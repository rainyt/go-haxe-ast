package game.world;

import game.utils.TimeUtils;
import game.world.data.RoleDebuff;
import openfl.display.Sprite;
import game.utils.Pool;
import openfl.utils.ObjectPool;
import differ.Collision;
import differ.Collision.Results;
import zygame.components.ZQuad;
import zygame.utils.FPSDebug;
import game.world.data.OffestPoint;
import pathfinder.Coordinate;
import game.events.RoleEvent;
import game.world.batch.HurtNumberLayer.HurtNumberStyle;
import zygame.utils.Lib;
import game.shader.RoleSpineShader;
import game.data.InteractiveData.HPData;
import game.shader.display.Effect;
import game.world.bullet.BaseBullet;
import motion.Actuate;
import game.data.ProduceUtils;
import zygame.core.Start;
import zygame.media.base.SoundChannel;
import game.world.data.VisibleRectangle;
import com.elnabo.quadtree.Box;
import game.world.ai.AiBase;
import differ.math.Vector;
import differ.shapes.Ray;
import game.data.quadtree.QuadShape;
import openfl.events.Event;
import game.script.RoleMove;
import game.view.state.HPLine;
import game.world.InteractiveType;
import game.world.data.WorldData;
import zygame.components.ZModel;
import game.world.data.WorldData.DisplayData;
import script.core.IScript;
import game.world.script.ScriptManager;
import game.world.interactives.Dialog;
import openfl.display.DisplayObject;
import spine.events.SpineEvent;
import differ.data.ShapeCollision;
import differ.shapes.Circle;
import differ.shapes.Shape;
import openfl.geom.Matrix;
import openfl.geom.Point;
import zygame.components.ZSpine;
import game.data.UserDataUtils;
import game.world.IDisplay;

using game.utils.IDisplayUtils;
using game.utils.EventUtils;
using game.utils.DynamicUtils;

/**
 * 角色基类，如动物、史小坑，都应继承Role类，实现统一的动作
 * idle
 * run
 */
class Role extends AsyncSpine implements IDisplay {
	/**
	 * 光源参数
	 */
	public var light:game.world.data.LightData;

	/**
	 * 无敌时间，按FPS计算
	 */
	public var invincible:Int = 0;

	/**
	 * 角色DEBUFF
	 */
	public var debuff:RoleDebuff = new RoleDebuff();

	/**
	 * 置低等级，等级越高，则会越在下面
	 */
	public var bottomLevel:Int = 0;

	/**
	 * 是否在船上
	 */
	public var inShip:Bool = false;

	/**
	 * 敌人的受伤目标
	 */
	public var hurtOffestTarget:Point = new Point();

	/**
	 * 角色队伍
	 */
	public var roleTroop:RoleTroop = ROLE;

	/**
	 * 渲染效果
	 */
	public var effect(default, set):Effect;

	function set_effect(value:Effect):Effect {
		if (effect != null && effect != value) {
			effect.dispose();
		}
		this.effect = value;
		return value;
	}

	/**
	 * 是否在海边
	 */
	public var inSeaside:Bool = false;

	private var seasidePos:Point = new Point();

	/**
	 * 获取海边的方向
	 * @return String
	 */
	public function getSeasideDirection():Point {
		var d = 300;
		if (!this.world.mapLayerShapes.testPoint(this.x - d, this.y)) {
			seasidePos.x = this.x - d;
			seasidePos.y = this.y;
			return seasidePos;
		} else if (!this.world.mapLayerShapes.testPoint(this.x + d, this.y)) {
			seasidePos.x = this.x + d;
			seasidePos.y = this.y;
			return seasidePos;
		} else if (!this.world.mapLayerShapes.testPoint(this.x, this.y - d)) {
			seasidePos.x = this.x;
			seasidePos.y = this.y - d;
			return seasidePos;
		} else if (!this.world.mapLayerShapes.testPoint(this.x, this.y + d)) {
			seasidePos.x = this.x;
			seasidePos.y = this.y + d;
			return seasidePos;
		}
		return null;
	}

	/**
	 * AI代理，当有设置AI代理时，会对它进行运算处理
	 */
	public var ai:AiBase;

	/**
	 * 脏状态，当发生脏状态时，则需要对它进行updateVisibleRect处理
	 */
	public var dirty:Bool = false;

	/**
	 * 提供给AiBase计算的时间确定器
	 */
	public var aiTime:Int = 0;

	/**
	 * 角色的方向是否为反向
	 */
	public var reverse:Bool = false;

	/**
	 * 角色操作是否被锁定，如果是锁定状态，则无法通过摇杆控制角色
	 */
	public var lock:Bool = false;

	/**
	 * 位图的偏移值
	 */
	public var offest:OffestPoint = new OffestPoint();

	/**
	 * 是否已经被破坏
	 */
	public var destroyed:Bool = false;

	/**
	 * 世界绑定
	 */
	public var world:World;

	/**
	 * 位图的可视化区域，如果不存在，则会以坐标为监测点
	 */
	public var visibleRect:VisibleRectangle = null;

	/**
	 * 移动时使用的碰撞块
	 */
	public var moveShapeBody:Shape;

	/**
	 * 移动射线，用于优化移动检测使用
	 */
	public var moveRay:Ray;

	/**
	 * 碰撞体，用于检测碰撞使用
	 */
	public var shapeBody:Shape;

	/**
	 * 交互碰撞体，用于检测是否有可以交互的物件
	 */
	public var actionBody:Shape;

	/**
	 * 资源ID
	 */
	public var assetsId:String;

	/**
	 * 原始路径数据
	 */
	public var rootPathData:Dynamic;

	/**
	 * 当前等待交互的对象
	 */
	public var waitInteractiveDisplay:IDisplay;

	/**
	 * 待机覆盖动作，当存在待机覆盖动作时，待机的时候会循环播放
	 */
	public var idleAction:String = null;

	/**
	 * 默认动作配置
	 */
	public var actionConfig:RoleActionConfig = {}

	public var offestMode:OffestMode = BOTTOM;

	/**
	 * 当前是否存在正在运行的逻辑
	 */
	public var currentPupil:Pupil;

	/**
	 * 当前是否存在正在运行的对话框
	 */
	public var currentDialog:Dialog;

	/**
	 * 当前播放的音频渠道
	 */
	private var soundChannel:SoundChannel;

	/**
	 * 身体颜色，用于制作受伤颜色使用，有效值0-1，约接近1越白
	 */
	public var bodyColor:Float = 0;

	public function new(spineName:String) {
		super();
		this.assetsId = spineName;
		this.moveShapeBody = new Circle(0, 0, 20);
		this.moveRay = new Ray(new Vector(), new Vector());
		actionBody = new Circle(0, 0, 250);
		Start.current.watch(this);
	}

	public function onTest():Void {}

	override function createSpine(atlasName:String, skeletionName:String) {
		super.createSpine(atlasName, skeletionName);
		if (this.getNativeSpine().skeleton.data.findSkin("pf1") != null)
			this.spineSkin = "pf1";
		if (this.getNativeSpine().state.getData().skeletonData.findAnimation("daiji") != null)
			actionConfig.idle = "daiji";
		else if (this.getNativeSpine().state.getData().skeletonData.findAnimation("idle") != null)
			actionConfig.idle = "idle";

		if (this.getNativeSpine().state.getData().skeletonData.findAnimation("run") != null)
			actionConfig.run = "run";
		else if (this.getNativeSpine().state.getData().skeletonData.findAnimation("walk") != null)
			actionConfig.run = "walk";
		// todo 这里应该使用更智能的检查
		this.setMixByName(actionConfig.run, actionConfig.idle, 0.1);
		this.setMixByName("idle_happy_learn", actionConfig.idle, 0.1);
		this.setMixByName(InteractiveType.AXE, actionConfig.idle, 0.1);
		this.setMixByName(InteractiveType.AXEPICK, actionConfig.idle, 0.1);

		// this.setMixByName(InteractiveType.SHOVEL, actionConfig.idle, 0.1);
		this.getNativeSpine().addEventListener(SpineEvent.EVENT, onSpineEvent);
		this.getNativeSpine().addEventListener(SpineEvent.COMPLETE, onSpineCompleteEvent);

		this.getNativeSpine().shader = RoleSpineShader.shader;

		// 渲染之前，调整着色器
		this.getNativeSpine().onRenderBefore = onSpineRenderBeFore;

		#if test
		// this.getNativeSpine().timeScale = 2;
		#end
	}

	public function onSpineRenderBeFore():Void {
		this.getNativeSpine().shader = RoleSpineShader.shader;
		RoleSpineShader.shader.u_addColor.value[0] = bodyColor;
	}

	override function onInit() {
		super.onInit();
		this.createSpine(assetsId, assetsId);
		this.onInitAi();
	}

	private var __moveToPupil:Pupil;

	/**
	 * 停止路线移动
	 */
	public function stopToPath():Void {
		if (__moveToPupil != null) {
			__moveToPupil.stop();
			moveHitTest = defaultMoveHitTest;
		}
	}

	/**
	 * 恢复路线移动
	 */
	public function resumeToPath():Void {
		if (__moveToPupil != null) {
			__moveToPupil.start(true);
			moveHitTest = false;
		}
	}

	/**
	 * 根据提供的路线进行移动
	 * @param path 
	 */
	public function moveToPath(path:Array<Coordinate>, moveed:Int->Void = null, nomapstep:Bool = false, autoStop:Bool = true):Void {
		if (this.world == null)
			return;
		if (path == null) {
			moveHitTest = defaultMoveHitTest;
			return;
		}
		if (__moveToPupil != null) {
			__moveToPupil.stop();
		}
		// 运行寻路移动程序
		var mapstep = cast(this.world, AiStarWorld).mapstep;
		var pupil = new Pupil();
		for (index => coordinate in path) {
			if (nomapstep || index == path.length - 1) {
				var m = new RoleMove(coordinate.x, coordinate.y);
				m.autoStop = autoStop;
				pupil.addScript(m, this);
			} else {
				var m = new RoleMove(coordinate.x * mapstep, coordinate.y * mapstep);
				m.autoStop = autoStop;
				pupil.addScript(m, this);
			}
		}
		__moveToPupil = pupil;
		pupil.onExit = function(code) {
			moveHitTest = defaultMoveHitTest;
			if (moveed != null)
				moveed(code);
		};
		pupil.start();
		moveHitTest = false;
	}

	private function onSpineCompleteEvent(e:SpineEvent):Void {
		if (this._action == "dance1" || this._action == "dance2" || this._action == "dance3")
			return;
		if (this._action == "dead")
			return;
		var eventName = e.type;
		if (_events.exists(eventName))
			_events.get(eventName)();
		if (this.action == "sickle") {
			roleState = NONE;
			stopAction(true);
		} else if (this.action == "open" || this.action == "newAnimal") {
			// 打开宝箱
			roleState = NONE;
			stopAction(true);
		} else if (this.action == "newWeapon") {
			roleState = NONE;
			startAction("idle_happy_newWeapon");
		} else if (this.action == "learn") {
			roleState = NONE;
			startAction("idle_happy_learn");
		} else if (this.action == "get") {
			roleState = NONE;
			stopAction(true);
		} else if (waitInteractiveDisplay != null) {
			if (waitInteractiveDisplay.parent == null || !waitInteractiveDisplay.canInteractive(this)) {
				// 当交互的对象已经消失了，则清除交互动作
				this.clearWaitInteractive();
				roleState = NONE;
				stopAction();
			}
		} else if (waitInteractiveDisplay == null
			|| waitInteractiveDisplay.interactiveEnble == false
			|| waitInteractiveDisplay.interactiveType != this.action) {
			roleState = NONE;
			stopAction();
		}
	}

	/**
	 * 事件回调映射
	 */
	private var _events:Map<String, Void->Void> = [];

	/**
	 * 侦听事件触发，如果设置的cb是null，则会删除侦听
	 * @param eventName 
	 * @param cb 
	 */
	public function event(eventName:String, cb:Void->Void):Void {
		if (cb == null)
			_events.remove(eventName);
		else
			_events.set(eventName, cb);
	}

	public function clearAllEvent():Void {
		_events.clear();
	}

	/**
	 * 更新角色的坐标
	 * @param x 
	 * @param y 
	 */
	public function updateXY(x:Float, y:Float):Void {
		this.point.x = x;
		this.point.y = y;
		this.x = this.point.x;
		this.y = this.point.y;
		this.updateVisibleRect();
	}

	private function onSpineEvent(e:SpineEvent):Void {
		// 事件回调
		var eventName = e.event.toString();
		if (_events.exists(eventName))
			_events.get(eventName)();
		if (waitInteractiveDisplay == null)
			return;
		switch (eventName) {
			case "interact":
				switch (waitInteractiveDisplay.interactiveType) {
					case InteractiveType.AXE:
						// 斧头声音
						this.world.assets.playSound("mc1003");
					case InteractiveType.SHOVEL:
						// 斧头声音
						this.world.assets.playSound("mc1004");
					case InteractiveType.AXEPICK:
						// 斧头声音
						this.world.assets.playSound("mc1005");
				}
				roleState = INTERACT;
				waitInteractiveDisplay.interactive(this, this.getNativeSpine().actionName);
				// 显示交互状态
				HPLine.show(waitInteractiveDisplay);
				var data:HPData = waitInteractiveDisplay != null ? waitInteractiveDisplay.interactiveData : null;
				if (data != null && data.hp == 0) {
					this.stopAction();
				}
			case "get":
				if (roleState == GET)
					return;
				if (waitInteractiveDisplay.interactiveType != InteractiveType.GET)
					return;
				if (topDisplay != null && topDisplay.length > 0)
					return;
				roleState = GET;
				waitInteractiveDisplay.interactive(this, this.getNativeSpine().actionName);
				// 在这里实现
				this.topDisplay = [cast(waitInteractiveDisplay, IDisplay)];
				Actuate.tween(waitInteractiveDisplay, 0.25, {}).onUpdate((display:IDisplay) -> {
					// 捡起动画
					var bone = this.getNativeSpine().skeleton.findBone("RHand3");
					var offestY = (display.offest.y);
					var tarX = this.x + bone.getWorldX() * this.scaleX - display.offest.x;
					var tarY = this.y + bone.getWorldY() - offestY;
					display.scaleX -= (display.scaleX - 0.) * 0.1;
					display.scaleY -= (display.scaleY - 0.) * 0.1;
					display.x -= (display.x - tarX - display.offest.x * (1 - display.scaleX)) * 1;
					display.y -= (display.y - tarY - offestY * (1 - display.scaleX)) * 1;
				}, [waitInteractiveDisplay]).onComplete((display:IDisplay) -> {
					if (display != null) {
						getProp(display);
						this.topDisplay = null;
						this.clearWaitInteractive();
					}
				}, [waitInteractiveDisplay]);
		}
	}

	/**
	 * 统一的捡取道具实现
	 * @param id 
	 * @param counts 
	 */
	public function getProp(display:IDisplay):Void {
		var id = ProduceUtils.getMaterialsIdByIDisplay(display);
		var counts:Float = display.materialCounts;
		if (counts <= 0)
			counts = 1;
		if (id != null) {
			var prop = UserDataUtils.materials.getDataById(id);
			if (prop != null) {
				// 展示捡取提示
				this.world.state.showPropGetAnimate(this, prop, counts);
				// 捡取完成
				UserDataUtils.addProp(prop.id, counts);
				// 如果是装饰，则刷新
				if (prop.type == "5") {
					var makedata = UserDataUtils.make.getDataById(prop.equipment);
					if (makedata != null && makedata.makeattrtype == "ar1004") {
						Lib.setTimeout(function() {
							// 增加收益
							this.world.state.showShellSpeedAnimate(this, {
								attrvalue: makedata.makeattr1,
								goodspoint: null
							});
							this.world.worldState.mathRevenuePerSecond();
						}, 1000);
					}
				}
			} else {
				ZModel.showTextModel("不存在[" + id + "]材料数据");
			}
		} else {
			ZModel.showTextModel("不存在materialId，导致无法正常捡取道具");
		}
		// 删除交互物件
		display.destroyThis(true);
	}

	/**
	 * 当前角色的位置
	 */
	public var point:Point = new Point();

	/**
	 * 移动速度
	 */
	public var speedMove:Point = new Point();

	/**
	 * 击退值
	 */
	private var _hitMove:Point = new Point();

	/**
	 * 击退生效时长
	 */
	private var hitTime:Float = 0;

	/**
	 * 最大击退生效时长
	 */
	private var maxHitTime:Float = 0;

	/**
	 * 移动检测长度
	 */
	private var lenMove:Point = new Point();

	/**
	 * 自身的移动速度
	 */
	public var speed:Float = 7;

	/**
	 * 当前移动强度
	 */
	public var influence:Float = 0;

	/**
	 * 当前移动角度
	 */
	public var radian:Float = 0;

	public function updateTransforms(t:Matrix):Void {
		var newPoint = t.transformPoint(point);
		this.x = newPoint.x;
		this.y = newPoint.y;
	}

	/**
	 * 设置角色的移动方向
	 * @param radian 移动方向
	 * @param touchInfluence 移动强度（影响移动速度）
	 * @param isHit 是否击退
	 */
	public function move(radian:Float, touchInfluence:Float):Void {
		this.radian = radian;
		var mx = Math.cos(radian) * 1;
		var my = Math.sin(radian) * 1;
		lenMove.x = 50 * mx;
		lenMove.y = 50 * my;
		speedMove.x = speed * mx;
		speedMove.y = speed * my;
		influence = touchInfluence;
	}

	/**
	 * 击退
	 * @param radian 击退角度
	 * @param speed 击退速度
	 * @param time 击退持续时长
	 */
	public function hitMove(radian:Float, speed:Float, time:Float):Void {
		this.radian = radian;
		var mx = Math.cos(radian) * 1;
		var my = Math.sin(radian) * 1;
		lenMove.x = 50 * mx;
		lenMove.y = 50 * my;
		_hitMove.x = speed * mx;
		_hitMove.y = speed * my;
		hitTime = time;
		maxHitTime = hitTime;
	}

	/**
	 * 造成伤害
	 * @param hurt 造成的伤害
	 * @param hurtBullet 造成伤害的子弹
	 */
	public function hurt(value:Int, hurtBullet:BaseBullet, hurtStyle:HurtNumberStyle = null):Int {
		if (value == 0 || interactiveData == null || invincible > 0 || getHPData().hp == 0) {
			return 0;
		}
		getHPData().add(-value);
		if (getHPData().hp == 0) {
			this.onDie();
		}
		bodyColor = 0.65;
		// 产生攻击伤害
		if (value > 0 && hurtBullet != null)
			World.currentWorld.numbersLayer.createNumber(value, hurtBullet.x + 50 - Std.random(100), hurtBullet.y + 50 - Std.random(100),
				hurtBullet.bulletData.hurtcolor != null ? hurtBullet.bulletData.hurtcolor : null, hurtStyle, hurtBullet.boomHit);
		else {
			World.currentWorld.numbersLayer.createNumber(value, this.x + 50 - Std.random(100), this.y - 130 + 50 - Std.random(100), null, hurtStyle);
		}
		return value;
	}

	/**
	 * 触发死亡
	 */
	public function onDie():Void {
		this.stopAction();
		// 兼容不存在daed的角色
		if (this.getNativeSpine().skeleton.data.findAnimation("dead") != null)
			this.startAction("dead", 1);
		// 发送角色死亡事件
		if (this.hasEventListener(RoleEvent.ROLE_DIE))
			this.dispatchEvent(new Event(RoleEvent.ROLE_DIE));
		// 爆出物品
		createGoodsByIDisplay(this);
	}

	/**
	 * 获取当前怪物的血量情况
	 * @return HPData
	 */
	public function getHPData():HPData {
		return this.interactiveData;
	}

	/**
	 * 添加HP
	 * @param hp 
	 */
	public function addHp(hp:Int):Void {
		this.getHPData().add(hp);
		if (this.hasEventListener(RoleEvent.UPDATE_HP))
			this.dispatchEvent(new Event(RoleEvent.UPDATE_HP));
	}

	/**
	 * 四叉树检测数组，每次moveMath都会更新一次
	 */
	private var _testQuadShapes:Array<QuadShape>;

	private var _testMapQuadShapes:Array<QuadShape>;

	/**
	 * 移动碰撞的计算次数
	 */
	public inline static var moveStepCounts = 2;

	/**
	 * moveMath时是否检测碰撞，当使用movePath方法时，将不会检测碰撞，因为路径已经是检测过可行性
	 */
	public var moveHitTest:Bool = true;

	/**
	 * 默认移动碰撞
	 */
	public var defaultMoveHitTest:Bool = true;

	/**
	 * 强制测试的碰撞区域，当存在强制碰撞测试时，则不会与maplayer进行碰撞，而只跟当前碰撞区域进行强制边缘碰撞
	 */
	public var forceTestHitShape:Shape = null;

	/**
	 * 地图边缘、物品碰撞移动算法
	 * @param moveX 移动的方向X
	 * @param moveY 移动的方向Y
	 * @param fixMove 碰撞到边缘时，是否进行修正位移
	 */
	public function moveMath(moveX:Float, moveY:Float, fixMove:Bool = true):Void {
		var lastX = this.x;
		var lastY = this.y;
		var pMoveHitTest = moveHitTest;
		// todo 地图的海边拐角没有碰撞
		// if (pMoveHitTest) {
		// 	// 先检查一下这附近格子的碰撞情况
		// 	var pidX = Std.int(this.point.x / 100);
		// 	var pidY = Std.int(this.point.y / 100);
		// 	var astarWorld:AiStarWorld = cast this.world;
		// 	var offest = @:privateAccess astarWorld.__offest;
		// 	var bool = astarWorld.isWalkable(pidX - offest.x, pidY - offest.y)
		// 		&& astarWorld.isWalkable(pidX - offest.x + 1, pidY - offest.y)
		// 		&& astarWorld.isWalkable(pidX - offest.x - 1, pidY - offest.y)
		// 		&& astarWorld.isWalkable(pidX - offest.x, pidY - offest.y + 1)
		// 		&& astarWorld.isWalkable(pidX - offest.x, pidY - offest.y - 1)
		// 		&& astarWorld.isWalkable(pidX - offest.x + 1, pidY - offest.y + 1)
		// 		&& astarWorld.isWalkable(pidX - offest.x - 1, pidY - offest.y - 1)
		// 		&& astarWorld.isWalkable(pidX - offest.x - 1, pidY - offest.y + 1)
		// 		&& astarWorld.isWalkable(pidX - offest.x + 1, pidY - offest.y - 1);
		// 	if (bool) {
		// 		pMoveHitTest = false;
		// 	}
		// }
		if (!pMoveHitTest) {
			var speedUpdate = Start.current.frameDtScale;
			this.point.x += moveX * speedUpdate;
			this.point.y += moveY * speedUpdate;
			this.x = point.x;
			this.y = point.y;
			__updateVisibleRect(lastX, lastY);
			this.world.updateSortLayer();
			return;
		}
		// 时间加速处理
		var speedUpdate = Start.current.frameDtScale;
		moveX *= speedUpdate;
		moveY *= speedUpdate;
		inSeaside = false;
		moveRay.start.x = this.x;
		moveRay.start.y = this.y;
		moveRay.end.x = moveRay.start.x + lenMove.x;
		moveRay.end.y = moveRay.start.y + lenMove.y;
		_testQuadShapes = this.world.shapes.getQuadtree(this.moveShapeBody, true);
		_testMapQuadShapes = this.world.mapLayerShapes.getQuadtree(this.moveShapeBody, false);
		// TODO 这里使用移动碰撞块先预检测一下，如果有碰撞，则开始计算
		this.moveShapeBody.x += moveX;
		this.moveShapeBody.y += moveY;
		var isHit = this.world.shapes.testQuadtree(this.moveShapeBody, _testQuadShapes) != null
			|| this.world.mapLayerShapes.testQuadtree(this.moveShapeBody, _testMapQuadShapes) == null;
		this.moveShapeBody.x -= moveX;
		this.moveShapeBody.y -= moveY;
		if (!isHit) {
			this.point.x += moveX;
			this.point.y += moveY;
			this.x = point.x;
			this.y = point.y;
			__updateVisibleRect(lastX, lastY);
			this.world.updateSortLayer();
			return;
		}
		var setpX = moveX / Std.int(speed * speedUpdate);
		var setpY = moveY / Std.int(speed * speedUpdate);
		_moveMath(moveX, moveY, setpX, setpY, fixMove);
		this.x = point.x;
		this.y = point.y;
		// todo这里尝试直接更新x/y，不直接调用updateVisibleRect();
		__updateVisibleRect(lastX, lastY);
		inSeaside = this.getSeasideDirection() != null;
		// 通知世界刷新层级关系
		this.world.updateSortLayer();
	}

	public function onInitAi():Void {}

	private function __updateVisibleRect(lastX:Float, lastY:Float):Void {
		if (visibleRect != null) {
			this.visibleRect.x += (this.x - lastX);
			this.visibleRect.y += (this.y - lastY);
			this.world.visibleWorldQuadtree.remove(this);
			this.world.visibleWorldQuadtree.add(this);
		}
		if (shapeBody != null) {
			this.shapeBody.x = this.x;
			this.shapeBody.y = this.y;
			this.shapeBody.scaleX = this.scaleX;
			this.shapeBody.scaleY = this.scaleY;
			this.shapeBody.rotation = this.rotation;
			cast(this.shapeBody, QuadShape).change = true;
			this.world.shapes.quadtree.remove(cast this.shapeBody);
			this.world.shapes.quadtree.add(cast this.shapeBody);
		}
	}

	private function _moveMath(moveX:Float, moveY:Float, setpX:Float, setpY:Float, fixMove:Bool = true):Void {
		var lastX = point.x;
		var lastY = point.y;
		for (i in 0...Std.int(speed * Start.current.frameDtScale)) {
			point.x += setpX;
			point.y += setpY;
			// 碰撞检测
			if (moveShapeBody != null) {
				moveShapeBody.x = point.x;
				moveShapeBody.y = point.y;
			}
			var ret = this.world.shapes.testQuadtree(this.moveShapeBody, _testQuadShapes);
			if (ret != null) {
				if (ret.length == 1)
					for (i in 0...ret.length) {
						_separation(ret.get(0));
						var ret = this.world.shapes.testQuadtree(this.moveShapeBody, _testQuadShapes);
						if (ret != null) {
							point.x = lastX;
							point.y = lastY;
						}
					}
				else {
					point.x -= setpX;
					point.y -= setpY;
					break;
				}
			}
			if (_moveMapLayer(moveX, moveY, setpX, setpY, lastX, lastY, fixMove)) {
				break;
			}
		}
	}

	private function _moveMapLayer(moveX:Float, moveY:Float, setpX:Float, setpY:Float, lastX:Float, lastY:Float, fixMove:Bool = true):Bool {
		var ret1:Results<ShapeCollision> = null;
		if (forceTestHitShape != null) {
			var r = forceTestHitShape.test(this.moveShapeBody);
			if (r != null) {
				ret1 = new Results(1);
				ret1.push(r);
			}
		}
		if (ret1 == null) {
			ret1 = this.world.mapLayerShapes.testQuadtree(this.moveShapeBody, _testMapQuadShapes);
		}
		if (ret1 == null) {
			point.x -= setpX;
			point.y -= setpY;
			if (moveShapeBody != null) {
				moveShapeBody.x = point.x;
				moveShapeBody.y = point.y;
			}
			if (fixMove) {
				// 在这里进行位移修正
				// var ret = this.world.mapLayerShapes.test(this.moveShapeBody);
				var ret = this.world.mapLayerShapes.testQuadtree(this.moveShapeBody, _testMapQuadShapes);
				#if test
				// 新的边缘计算
				if (ret == null) {
					point.x = lastX;
					point.y = lastY;
				} else {
					// todo 这里要改进，这里会卡墙的风险，特别是纯三角形
					var hitdata = ret.iterator().next();
					var speed = Math.abs(Math.max(moveX, moveY));
					point.x -= hitdata.unitVectorX * speed;
					point.y -= hitdata.unitVectorY * speed;
					_moveMath(moveX, moveY, setpX, setpY, false);
				}
				#elseif false
				if (ret == null) {
					point.x = lastX;
					point.y = lastY;
				} else {
					var hitdata = ret.iterator().next();
					trace("绘制", cast(hitdata.shape2, QuadShape).vertices);
					World.currentWorld.debug.clear();
					// World.currentWorld.debug.drawShape(hitdata.shape1);
					World.currentWorld.debug.drawShape(hitdata.shape2);
					// World.currentWorld.debug.drawShapeCollision(hitdata);

					var oldx = hitdata.shape1.x;
					var oldy = hitdata.shape1.y;
					hitdata.shape1.x = oldx + hitdata.separationX;
					hitdata.shape1.y = oldy + hitdata.separationY;
					World.currentWorld.debug.drawShape(hitdata.shape1);

					hitdata.shape1.x = oldx + hitdata.otherSeparationX;
					hitdata.shape1.y = oldy + hitdata.otherSeparationY;
					World.currentWorld.debug.drawShape(hitdata.shape1);

					World.currentWorld.debug.drawLine(hitdata.shape1.position.x, hitdata.shape1.position.y,
						hitdata.shape1.position.x + (hitdata.unitVectorX * 30), hitdata.shape1.position.y + (hitdata.unitVectorY * 30));

					World.currentWorld.debug.display.fillEnd();
					World.currentWorld.debug.display.x = world.box.x;
					World.currentWorld.debug.display.y = world.box.y;
					World.currentWorld.debug.display.scale(world.box.scaleX);

					var length = 5;

					// var a = Lib.angleToRadian(90);
					// var s = Math.sin(a);
					// var c = Math.cos(a);
					point.x += -(hitdata.unitVectorX) * length;
					point.x += -(hitdata.unitVectorY) * length;
					_moveMath(moveX, moveY, setpX, setpY, false);

					// var s = new Sprite();
					// s.graphics.lineStyle(5, 0xff0000);
					// s.graphics.moveTo(hitdata.shape1.position.x, hitdata.shape1.position.y);
					// s.graphics.lineTo(hitdata.shape1.position.x + (hitdata.unitVectorX * length * 10),
					// 	hitdata.shape1.position.y + (hitdata.unitVectorY * length * 10));
					// World.currentWorld.topBox.addChild(s);
					// point.x -= hitdata.unitVectorX * length;
					// point.y -= hitdata.unitVectorY * length;
					// trace(hitdata.unitVectorX * length, hitdata.unitVectorY * length);
					// _moveMath(moveX * 2, moveY * 2, setpX, setpY, false);
					// World.currentWorld.debug.drawLine(hitdata.shape1.position.x, hitdata.shape1.position.y,
					// hitdata.shape1.position.x + (hitdata.unitVectorX * length), hitdata.shape1.position.y + (hitdata.unitVectorY * length));
				}
				#else
				if (ret == null) {
					point.x = lastX;
					point.y = lastY;
				} else {
					// todo 这里要改进，这里会卡墙的风险，特别是纯三角形
					var hitdata = ret.iterator().next();
					point.x -= hitdata.separationX * 10;
					point.y -= hitdata.separationY * 10;
					_moveMath(moveX * 2, moveY * 2, setpX, setpY, false);
				}
				#end
			}
			if (forceTestHitShape != null) {
				if (forceTestHitShape.data == world.ship) {
					world.ship.onMoveToEdge();
				}
			}
			return true;
		} else {
			if (ret1.length == 1) {
				var c = ret1.get(0);
			}
		}
		return false;
		// Collision.rayWithShapes(null,cast_testMapQuadShapes);
		// if (ret1 != null) {
		// 	// 计算分离
		// 	var nowX = this.moveShapeBody.x;
		// 	var nowY = this.moveShapeBody.y;
		// 	for (c in ret1) {
		// 		this.moveShapeBody.x -= c.separationX;
		// 		this.moveShapeBody.y -= c.separationY;
		// 		point.x -= c.separationX;
		// 		point.y -= c.separationY;
		// 		return true;
		// 	}
		// 	// if (ret1.length == 1) {
		// 	// 	// 需要计算边缘
		// 	// 	var c = ret1.get(0);
		// 	// 	point.x -= c.separationX;
		// 	// 	point.y -= c.separationY;
		// 	// 	point.x += 50 * Math.cos(c.unitVectorX);
		// 	// 	point.y += 50 * Math.sin(c.unitVectorY);
		// 	// 	return true;
		// 	// }
		// }
	}

	public function onFrame30() {
		invincible -= invincible > 0 ? 2 : 0;
		if (Math.abs(influence) > 0.3) {
			// 当角色的移动强度大于0.3时，意味着正在移动，需要检查交互，否则无需检查
			testInteractive();
		}
	}

	/**
	 * 测试是否存在有可交互的动作
	 */
	public function testInteractive(force:Bool = false):Void {
		// 仅在NONE状态下查找
		// trace("testInteractive", this.roleState);
		if ((force || this.roleState == NONE) && waitInteractiveDisplay != null) {
			this.waitInteractiveDisplay.onInteractiveOut(this);
			this.waitInteractiveDisplay = null;
			this.postEvent(INTERACTIVE_CHANGE);
		}
		if (inShip) {
			return;
		}
		// todo 是否会影响交互对象发生变化？
		if (this.waitInteractiveDisplay != null
			&& this.waitInteractiveDisplay.interactiveType != InteractiveType.HAMMERING
			&& this.roleState != NONE)
			return;
		if (this.world != null) {
			var oldWait = waitInteractiveDisplay;
			if (oldWait == null) {
				waitInteractiveDisplay = world.getInteractiveBitmapDisplayAtRole(this);
				if (waitInteractiveDisplay != null) {
					waitInteractiveDisplay.onInteractiveOver(this);
					this.postEvent(INTERACTIVE_CHANGE);
					cast(this, SxkRole).ets.onInteractiveOver(waitInteractiveDisplay);
				}
			} else {
				waitInteractiveDisplay = world.getInteractiveBitmapDisplayAtRole(this);
				// 这里如果根据actionBar.visible判断会有问题
				// || !this.world.state.actionBar.visible
				if (oldWait != waitInteractiveDisplay) {
					if (waitInteractiveDisplay != null)
						waitInteractiveDisplay.onInteractiveOver(this);
					oldWait.onInteractiveOut(this);
					this.postEvent(INTERACTIVE_CHANGE);
					cast(this, SxkRole).ets.onInteractiveOver(waitInteractiveDisplay);
				} else if (waitInteractiveDisplay == null) {
					oldWait.onInteractiveOut(this);
				}
			}
		}
	}

	/**
	 * 交互待定动作
	 */
	private var _action:String;

	/**
	 * 循环次数
	 */
	private var _loop:Int = -1;

	/**
	 * 当前角色状态
	 */
	public var roleState:RoleState = NONE;

	/**
	 * 开始某个交互行为动作，当该方法触发后，将会强制播放此交互动作
	 * @param action 交互动作
	 * @param loop 循环次数，当为-1则无限循环
	 */
	public function startAction(action:String, loop:Int = -1):Void {
		_action = action;
		_loop = loop;
	}

	/**
	 * 是否保留编程运行
	 */
	public var keepPupil:Bool = false;

	/**
	 * 停止交互行为，但保留当前运行的编程运行
	 * @param test 
	 */
	public function stopActionKeepPupil(test:Bool = false):Void {
		keepPupil = true;
		stopAction(test);
		keepPupil = false;
	}

	/**
	 * 停止交互行为
	 */
	public function stopAction(test:Bool = false):Void {
		if (!keepPupil && currentPupil != null)
			currentPupil.stop();
		if (roleState == GET) {
			return;
		}
		if (roleState != NONE && roleState != INTERACT) {
			return;
		}
		_action = null;
		if (!keepPupil)
			roleState = NONE;
		// 重新检查交互
		if (test)
			this.testInteractive();
	}

	private var _readyWaitInteractiveDisplay:IDisplay;

	/**
	 * 触发移动到指定位置后触发交互
	 */
	public function moveRoleInteractive():Void {
		if (waitInteractiveDisplay == null) {
			testInteractive(true);
		}
		if (waitInteractiveDisplay == null) {
			return;
		}
		if (waitInteractiveDisplay.interactiveType == InteractiveType.GET_FISH) {
			// 如果是捕鱼，则直接触发
		} else if (Std.isOfType(waitInteractiveDisplay, Role) || waitInteractiveDisplay.interactiveType == InteractiveType.DIRCT) {
			// 如果是角色，则直接交互
			this.roleState = INTERACT;
			if (roleInteractive()) {
				waitInteractiveDisplay.invalidate();
			}
		} else {
			// 移动逻辑
			this.roleState = INTERACT;
			_readyWaitInteractiveDisplay = waitInteractiveDisplay;
			if (currentPupil != null)
				currentPupil.stop();
			currentPupil = new Pupil();
			currentPupil.addScript(new RoleMove(waitInteractiveDisplay.getX(), waitInteractiveDisplay.getY()), this);
			currentPupil.onExit = function(code) {
				waitInteractiveDisplay = _readyWaitInteractiveDisplay;
				roleInteractive();
			}
			currentPupil.start();
		}
	}

	/**
	 * 开始交互
	 * @param igoneScript 忽略脚本执行
	 */
	public function roleInteractive(igoneScript:Bool = false):Bool {
		#if mapedit
		return false;
		#end
		if (waitInteractiveDisplay == null)
			return false;
		this.setFlip(this.x < (waitInteractiveDisplay.x + waitInteractiveDisplay.offest.x));
		// 先检查是否有独立少儿编程逻辑
		if (!igoneScript) {
			currentPupil = ScriptManager.runScript(waitInteractiveDisplay);
			if (currentPupil != null) {
				// World.currentWorld.state.hideState();
				currentPupil.onExit = function(code) {
					testInteractive();
					// 展示状态栏
					trace("剧情结束");
					// World.currentWorld.state.showState();
				}
			}
			return currentPupil == null;
		}
		this.roleState = INTERACT;
		return true;
	}

	public function onTrackAnimate():Void {}

	/**
	 * 特效渲染逻辑处理
	 */
	public function onEffectRender():Void {
		// 特效渲染
		if (effect != null) {
			if (effect.parent == null)
				this.world.topBox.addChild(effect);
			effect.x = this.x - effect.width / 2 + effect.offest.x;
			effect.y = this.y - effect.height / 2 + effect.offest.y;
			effect.onRender();
		}
		this.debuff.onRenderBuff(this);
	}

	public function onAiFrame() {
		#if !mapedit
		// AI运算逻辑，可视化AI与不可视化AI需要做区别，例如不可视化时仅做预测出现的位置。
		if (ai != null) {
			ai.onFrame();
			if (this.visible)
				ai.onVisibleFrame();
			else {
				ai.onHideFrame();
			}
		}
		#end
	}

	override function onFrame() {
		super.onFrame();
		bodyColor -= bodyColor > 0 ? 0.1 : 0;
		if (bodyColor < 0)
			bodyColor = 0;
		// 死亡动作兼容
		if (_action == "dead") {
			if (this.action != _action) {
				this.isLoop = false;
				this.action = _action;
			}
			return;
		}
		var action = (_action == null || inShip) ? (idleAction != null ? idleAction : actionConfig.idle) : _action;
		if (action == null)
			return;
		if (inShip) {
			if (influence > 0.3 && speedMove.x != 0) {
				this.setFlip(speedMove.x > 0);
			}
		} else if (hitTime <= 0) {
			if (action.indexOf("idle") != -1 && influence > 0.3) {
				idleAction = null;
				if (speedMove.x != 0) {
					this.setFlip(speedMove.x > 0);
				}
				action = actionConfig.run;
				// BUFF影响
				var moveSpeed = debuff.moveSpeed(speedMove);
				moveMath(moveSpeed.x, moveSpeed.y);
			}
		} else {
			// 击退逻辑
			moveMath(_hitMove.x * hitTime / maxHitTime, _hitMove.y * hitTime / maxHitTime);
			hitTime -= Start.current.frameDt;
		}
		if (this.action != action) {
			this.isLoop = true;
			this.action = action;
		}
		this.onTrackAnimate();
		this.x = point.x;
		this.y = point.y - this.offest.bottom;
		if (moveShapeBody != null) {
			moveShapeBody.x = this.x;
			moveShapeBody.y = this.y;
		}
		if (actionBody != null) {
			actionBody.x = this.x;
			actionBody.y = this.y;
		}
		// 交互onInteractiveFrame实现
		if (waitInteractiveDisplay != null && !this.lock) {
			waitInteractiveDisplay.onInteractiveFrame(this);
		}
	}

	/**
	 * 操作精细化分离
	 * @param collision 
	 */
	private function _separation(collision:ShapeCollision):Void {
		while (collision != null) {
			if (collision.unitVectorX != 0) {
				point.x += collision.unitVectorX;
			}
			if (collision.unitVectorY != 0) {
				point.y += collision.unitVectorY;
			}
			moveShapeBody.x = point.x;
			moveShapeBody.y = point.y;
			collision = collision.shape1.test(collision.shape2);
		}
	}

	public function updateVisibleRect() {
		updateVisibleRectByIDisplay(this);
	}

	public function isCanActionBar():Bool {
		if (this.currentPupil != null && this.currentPupil.isStart)
			return false;
		return true;
	}

	/**
	 * 身体的比例
	 */
	public var bodyScale:Float = 1;

	/**
	 * 设置是否翻转
	 * @param bool 
	 */
	public function setFlip(bool:Bool):Void {
		this.scaleX = (bool ? 1 : -1) * bodyScale;
		this.scaleY = bodyScale;
		if (reverse) {
			this.scaleX *= -1;
		}
	}

	/**
	 * 说话
	 * @param chat 
	 * @return Dialog
	 */
	public function showDialog(chat:String, removeTestInteractive:Bool = false, autoHide:Bool = false):Dialog {
		if (chat == null)
			chat = "";
		if (currentDialog != null && currentDialog.parent != null) {
			currentDialog.parent.removeChild(currentDialog);
		}
		currentDialog = new Dialog(this, chat);
		currentDialog.alwaysShow = !autoHide;
		if (!autoHide)
			Dialog.currentDialog = currentDialog;
		this.world.topBox.addChild(currentDialog);
		// TODO 这里是否需要再做一次检测，但如果存在多次调用，可能会有问题
		if (removeTestInteractive)
			currentDialog.addEventListener(Event.REMOVED_FROM_STAGE, function(e) {
				currentDialog = null;
				this.waitInteractiveDisplay = null;
				this.testInteractive();
			});
		this.world.assets.playSound("mc1033");
		return currentDialog;
	}

	override function get_width():Float {
		return this.getNativeSpine().skeleton.data.width;
	}

	override function get_height():Float {
		return this.getNativeSpine().skeleton.data.height;
	}

	/**
	 * 父节点的IDisplay，当存在这个时，该对象的层级要大于此层级
	 */
	public var topDisplay:Array<IDisplay>;

	public var materialId:String;

	public function getState():DisplayState {
		return {
			destroyed: destroyed,
			time: Std.int(TimeUtils.now() / 1000)
		};
	}

	override function localToGlobalInParentStart(point:Point):Point {
		point = this.world.box.localToGlobal(point);
		point = Start.current.globalToLocal(point);
		return point;
	}

	public function updateState(state:DisplayState) {}

	public var interactiveEnble:Bool;

	public var interactiveType:String;

	public function canInteractive(role:Role):Bool {
		return interactiveEnble;
	}

	public var interactiveData:Dynamic;

	public var scripts:Array<IScript> = [];

	public var displayData:DisplayData;

	public function interactive(role:Role, interactiveType:String) {}

	public var uid:Int = 0;

	public function destroyThis(bool:Bool) {
		this.destroyed = true;
		this.interactiveEnble = false;
		if (bool)
			this.world.worldState.asyncState(this);
		this.world.removeWorldDispaly(this);
		if (this.shapeBody != null)
			this.world.shapes.removeShapes(this.shapeBody);
		if (!this.worldCreate)
			this.world = null;
	}

	/**
	 * 清理目前交互的对象
	 */
	public function clearWaitInteractive():Void {
		if (waitInteractiveDisplay != null) {
			// trace("clearWaitInteractive");
			// waitInteractiveDisplay.interactiveEnble = false;
			waitInteractiveDisplay.onInteractiveOut(this);
			this.testInteractive();
			// this.postEvent(INTERACTIVE_CHANGE);
		}
		waitInteractiveDisplay = null;
	}

	public function onInteractiveFrame(role:Role) {
		// Role类暂无需实现
	}

	public function onInteractiveOver(role:Role) {}

	public function onInteractiveOut(role:Role) {}

	/**
	 * 当从对象进入舞台可视化区域时
	 */
	public function onStageOver() {}

	/**
	 * 当对象离开舞台可视化区域时
	 */
	public function onStageOut() {}

	/**
	 * 是否由World创建
	 */
	public var worldCreate:Bool = false;

	/**
	 * 是否允许重生
	 */
	public var allowRebirth:Bool = false;

	public function bindAssetsID(assestId:String) {}

	public function onStageFrame() {}

	public var materialCounts:Float;

	public var layerLock:Bool = false;

	/**
	 * 是否置低显示
	 */
	public var bottom:Bool = false;

	public var bottomDisplay:DisplayObject;

	public function box():Box {
		return this.toBoxByIDisplay();
	}

	public function reset() {
		if (this.interactiveData != null)
			this.getHPData().reset();
		this.updateVisibleRect();
		this.stopAction();
		this.idleAction = null;
	}

	/**
	 * 无消耗创建攻击
	 */
	public function createBulletNoConsumption(data:BulletData, x:Float, y:Float, addToBullets:Bool = true):BaseBullet {
		return createBulletBase(data, x, y, addToBullets);
	}

	private function createBulletBase(data:BulletData, x:Float, y:Float, addToBullets:Bool = true):BaseBullet {
		var b = Pool.bulletPool.get();
		data.scale = bodyScale;
		b.updateData(data);
		if (addToBullets)
			this.world.bulletsLayer.addBullet(b);
		b.x = x;
		b.y = y;
		b.parentRole = this;
		return b;
	}

	/**
	 * 发射子弹
	 * @param data 子弹数据
	 * @param x 产生坐标X
	 * @param y 产生坐标Y
	 * @param addToBullets 是否添加到子弹列表中
	 */
	public function createBullet(data:BulletData, x:Float, y:Float, addToBullets:Bool = true):BaseBullet {
		return createBulletBase(data, x, y, addToBullets);
	}

	/**
	 * 当子弹击中敌人触发
	 * @param enemy 
	 */
	public function onHitEnemy(enemy:Role, bullet:BaseBullet):Void {}

	public function dispose() {}
}

enum RoleState {
	// 无必要操作
	NONE;
	// 交互中
	INTERACT;
	// 捡取
	GET;
}

/**
 * 动作基础配置
 */
typedef RoleActionConfig = {
	?idle:String,
	?run:String
}

enum RoleTroop {
	// 敌人
	ENEMY;
	// 自已人
	ROLE;
}

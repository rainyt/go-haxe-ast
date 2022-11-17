package hxast

type Token = int

const (
	TEnd        = iota // 包
	TIgonre            // 可忽略的，例如空格
	TCommon            // 通用token
	TPackage           // 包名定义
	TImport            // 导入类
	TUsing             // Using类
	TNotes             // 注释
	TClass             // 类型
	TExtends           // 继承
	TImplements        // 接口
	TBlockOpen         // {
	TBlockClose        // }
	TPublic            // public
	TPrivate           // private
	TStatic            // static
	TInline            // inline
	TVar               // var
)

// Token，记录所有token的记录
type TokenKey struct {
	Token Token  // Token定义
	Key   string // Token字段
}

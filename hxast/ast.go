package hxast

import (
	"fmt"
	"os"
	"strings"
)

// 解析位置
type Pos struct {
	At     int // 当前文本位置
	Line   int // 当前行
	LineAt int // 当前行文本位置
	MaxAt  int // 最大有效位置
}

// AST数据结构体
type AST struct {
	Path       string      // 解析路径
	Tokens     []*TokenKey // Tokens列表
	TokensSize int         // Token长度
	Point      Pos         // 坐标
	Chars      []string    // 解析文本
	CacheToken string      // 缓存的token
}

// 将关键信息输出
func (ast *AST) ToString() {
	fmt.Println("Tokens:")
	for _, tk := range ast.Tokens {
		fmt.Printf("%s(%d)\n", tk.Key, tk.Token)
	}
	fmt.Println("Pos:")
	ast.ToPosString()
}

// 输出当前解析的位置坐标
func (ast *AST) ToPosString() {
	fmt.Printf("At:%d/%d Line:%d LineAt:%d\n", ast.Point.At, ast.Point.MaxAt, ast.Point.Line, ast.Point.LineAt)
}

// 开始解析Haxe文件
func ParserHaxe(path string) *AST {
	var ast = &AST{
		Path: path,
	}
	// 开始解析
	b, e := os.ReadFile(path)
	if e != nil {
		panic(e)
	}
	context := string(b)
	ast.Chars = strings.Split(context, "")
	ast.Point.MaxAt = len(ast.Chars)
	ast.Point.At = 0
	ast.Point.Line = 1
	ast.Point.LineAt = 0
	for {
		if ast.Point.At < ast.Point.MaxAt {
			// 逐个解析
			t, et := ast.ParserToken()
			switch t {
			case TEnd:
				break
			case TCommon:
				tk, terr := ast.CheckToken()
				if terr != nil && et == TIgonre {
					panic(terr)
				}
				if tk != nil {
					ast.Tokens = append(ast.Tokens, tk)
					ast.TokensSize++
				}
			}
			switch et {
			case TIgonre:
			default:
				// 指定类型:Class
				ast.Tokens = append(ast.Tokens, &TokenKey{
					Token: et,
				})
				ast.TokensSize++
			}
		} else {
			break
		}
	}
	return ast
}

// 解析Token
func (ast *AST) ParserToken() (Token, Token) {
	readEnd := false
	ast.CacheToken = ""
	var endToken Token = TIgonre
	for {
		char := ast.ReadChar()
		switch char {
		case "(":
			endToken = TRBlockOpen
			readEnd = true
		case ")":
			endToken = TRBlockOpen
			readEnd = true
		case "{":
			endToken = TBlockOpen
			readEnd = true
		case "}":
			endToken = TBlockClose
			readEnd = true
		case "=":
			endToken = TEqual
			readEnd = true
		case ":":
			endToken = TType
			readEnd = true
		case "\n", ",", " ", "	", ";":
			readEnd = true
			return TCommon, endToken
		}
		if !readEnd || len(ast.CacheToken) == 0 {
			ast.CacheToken += char
		}
		if readEnd || ast.Point.At == ast.Point.MaxAt {
			break
		}
	}
	if ast.Point.At == ast.Point.MaxAt {
		return TEnd, endToken
	} else {
		return TCommon, endToken
	}
}

// 读取一个字符
func (ast *AST) ReadChar() string {
	if ast.Point.At >= ast.Point.MaxAt {
		panic("无效的token结尾")
	}
	char := ast.Chars[ast.Point.At]
	if char == "\n" {
		ast.Point.Line++
		ast.Point.LineAt = 0
	} else {
		ast.Point.LineAt++
	}
	ast.Point.At++
	return char
}

// 检查token的合法性
func (ast *AST) CheckToken() (*TokenKey, error) {
	if len(ast.CacheToken) == 0 {
		return nil, nil
	}
	fmt.Println("检查", ast.CacheToken)
	switch ast.CacheToken {
	case "&&":
		return &TokenKey{
			Token: TAnd,
			Key:   ast.CacheToken,
		}, nil
	case "||":
		return &TokenKey{
			Token: TOr,
			Key:   ast.CacheToken,
		}, nil
	case "if":
		return &TokenKey{
			Token: TIf,
			Key:   ast.CacheToken,
		}, nil
	case "function":
		return &TokenKey{
			Token: TFunction,
			Key:   ast.CacheToken,
		}, nil
	case "default":
		return &TokenKey{
			Token: TDefault,
			Key:   ast.CacheToken,
		}, nil
	case "get":
		return &TokenKey{
			Token: TGet,
			Key:   ast.CacheToken,
		}, nil
	case "set":
		return &TokenKey{
			Token: TSet,
			Key:   ast.CacheToken,
		}, nil
	case "var":
		return &TokenKey{
			Token: TVar,
			Key:   ast.CacheToken,
		}, nil
	case "inline":
		return &TokenKey{
			Token: TInline,
			Key:   ast.CacheToken,
		}, nil
	case "public":
		return &TokenKey{
			Token: TPublic,
			Key:   ast.CacheToken,
		}, nil
	case "private":
		return &TokenKey{
			Token: TPrivate,
			Key:   ast.CacheToken,
		}, nil
	case "static":
		return &TokenKey{
			Token: TPrivate,
			Key:   ast.CacheToken,
		}, nil
	case "{":
		return &TokenKey{
			Token: TBlockOpen,
			Key:   ast.CacheToken,
		}, nil
	case "}":
		return &TokenKey{
			Token: TBlockClose,
			Key:   ast.CacheToken,
		}, nil
	case "implements":
		return &TokenKey{
			Token: TImplements,
			Key:   ast.CacheToken,
		}, nil
	case "extends":
		return &TokenKey{
			Token: TExtends,
			Key:   ast.CacheToken,
		}, nil
	case "class":
		return &TokenKey{
			Token: TClass,
			Key:   ast.CacheToken,
		}, nil
	case "package":
		// 包名下个token
		return &TokenKey{
			Token: TPackage,
			Key:   ast.CacheToken,
		}, nil
	case "import":
		// import
		return &TokenKey{
			Token: TImport,
			Key:   ast.CacheToken,
		}, nil
	case "using":
		return &TokenKey{
			Token: TUsing,
			Key:   ast.CacheToken,
		}, nil
	default:
		if strings.Index(ast.CacheToken, "/*") == 0 {
			// 注释内容，需要找到 */结束符
			char := ""
			for {
				char += ast.ReadChar()
				l := len(char)
				if l >= 2 {
					if char[l-2:] == "*/" {
						return &TokenKey{
							Token: TNotes,
							Key:   "/*" + char,
						}, nil
					}
				}
			}
		}
	}
	if ast.TokensSize > 0 {
		last := ast.Tokens[ast.TokensSize-1]
		switch last.Token {
		case TPackage, TImport, TUsing, TClass, TExtends, TImplements, TVar, TType, TEqual, TNew, TBlockOpen, TRBlockOpen, TAnd, TOr:
			// 可接收参数
			return &TokenKey{
				Token: TCommon,
				Key:   ast.CacheToken,
			}, nil
		default:
			ast.ToString()
			return nil, fmt.Errorf("上一个token:%s，未定义的token:%s %s:%d:%d", last.Key, ast.CacheToken, ast.Path, ast.Point.Line, ast.Point.LineAt)
		}
	}
	ast.ToString()
	return nil, fmt.Errorf("ast.TokensSize=%d, 未定义的token:%s %s:%d:%d", ast.TokensSize, ast.CacheToken, ast.Path, ast.Point.Line, ast.Point.LineAt)
}

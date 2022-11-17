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
		fmt.Printf(tk.Key + " ")
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
	var ast = &AST{}
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
			t := ast.ParserToken()
			switch t {
			case TEnd:
				break
			case TCommon:
				tk, terr := ast.CheckToken()
				if terr != nil {
					panic(terr)
				}
				ast.Tokens = append(ast.Tokens, tk)
				ast.TokensSize++
			}
		} else {
			break
		}
	}
	return ast
}

// 解析Token
func (ast *AST) ParserToken() Token {
	readStart := false
	readEnd := false
	ast.CacheToken = ""
	for {
		char := ast.ReadChar()
		if !readStart {
			if char == " " || char == "\n" {
				return TIgonre
			}
			readStart = true
			ast.CacheToken += char
		} else {
			// 判断结束
			switch char {
			case " ":
				readEnd = true
			case ";":
				readEnd = true
			}
			if !readEnd {
				ast.CacheToken += char
			}
		}
		if readEnd || ast.Point.At == ast.Point.MaxAt {
			break
		}
	}
	if ast.Point.At == ast.Point.MaxAt {
		return TEnd
	} else {
		return TCommon
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
	fmt.Println("检查", ast.CacheToken)
	switch ast.CacheToken {
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
		switch ast.Tokens[ast.TokensSize-1].Token {
		case TPackage, TImport, TUsing:
			// 可接收参数
			return &TokenKey{
				Token: TCommon,
				Key:   ast.CacheToken,
			}, nil
		}
	}
	return nil, fmt.Errorf("未定义的token:%s", ast.CacheToken)
}

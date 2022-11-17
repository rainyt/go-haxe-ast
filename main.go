package main

import (
	"flag"
	"fmt"
	"go-haxe-ast/hxast"
)

var (
	File = flag.String("file", "", "输入Haxe文件")
)

func main() {
	flag.Parse()
	fmt.Println("准备处理:" + *File)
	ast := hxast.ParserHaxe(*File)
	ast.ToString()
}

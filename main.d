module main;

import std.stdio;
import std.conv;
import reflection;
import test;

int main(string[] args)
{
    static const(Module) modRefl = reflect!test;
    static const(Class) classRefl = modRefl.getClass("Test1");

    writeln("Test1 fields:");

    foreach(const(Field) field; classRefl.fields) {
        writeln(field);
    }

    writeln();
    writeln("Test1 methods:");

    foreach(const(Method) method; classRefl.methods) {
        writeln(method);
    }

    writeln();
    writeln("Test1 properties:");

    foreach(const(Property) property; classRefl.properties) {
        writeln(property);
    }

    return 0;
}

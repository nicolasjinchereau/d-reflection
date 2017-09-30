### Reflection for the D programming language

```d
module main;

struct S {
    float x;
}

class C {
    private int _y;
    @property int y() const {
        return _y;
    }
    @property void y(int v) {
        _y = v;
    }
    void z() {
        writeln("hello reflection");
    }
}

int main(string[] args)
{
    S s;
    reflect!S.getField("x").setValue(s, 1);
    int x = cast(int)reflect!S.getField("x").getValue(s);
    assert(x == 1);

    C c = new C;
    reflect!C.getProperty("y").setValue(c, 2);
    int y = cast(int)reflect!C.getProperty("y").getValue(c);
    assert(y == 2);
    
    reflect!C.getMethod("z").invoke(c);
    
    // works at runtime as long as 'reflect!C' has been instantiated
    auto rt = cast(const(Class))reflect("main.C");
    rt.getMethod("z").invoke(c);
    
    return 0;
}
```

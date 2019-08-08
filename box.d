module box;
import std.meta;
import std.traits;
import std.stdio;

struct Box
{
    this(T)(auto ref T value) {
        opAssign(value);
    }

    this(this) {
        _fptr(&_store, Operation.Copy, &_store, null);
    }

    ~this() {
        _fptr(&_store, Operation.Destruct, null, null);
    }

    void opAssign(T)(auto ref T value)
    {
        _fptr(&_store, Operation.Destruct, null, null);

        static if(is(Unqual!T == Box))
        {
            _fptr = value._fptr;
            _fptr(&_store, Operation.Copy, &value._store, null);
        }
        else
        {
            alias U = UnqualR!T;
            _fptr = &fun!U;
            _fptr(&_store, Operation.Write, &value, null);
        }
    }

    T opCast(T)() if(isSupportedType!T)
    {
        static if(is(T == class) || is(T == interface))
        {
            Object obj;
            if(_fptr(cast(Storage*)&_store, Operation.Read, &obj, typeid(Object)))
            {
                static if(!is(T == Object)) {
                    if(obj is null) return null;
                    if(T ret = cast(T)obj) return ret;
                }
                else {
                    return obj;
                }
            }
        }
        else static if(isArray!T)
        {
            void[] arr;
            if(_fptr(cast(Storage*)&_store, Operation.Read, &arr, typeid(void[])))
                return cast(T)arr;
        }
        else static if(isPointer!T)
        {
            void* ptr;
            if(_fptr(cast(Storage*)&_store, Operation.Read, &ptr, typeid(void*)))
                return cast(T)ptr;
        }
        else static if(isSupportedScalarType!T)
        {
            alias U = UnqualR!T;
            int opAndFlags = Operation.Read | (staticIndexOf!(U, ScalarTypes) << 16);

            U ret;
            if(_fptr(cast(Storage*)&_store, opAndFlags, &ret, typeid(U)))
                return ret;
        }
        else
        {
            alias U = UnqualR!T;

            U ret;
            if(_fptr(cast(Storage*)&_store, Operation.Read, &ret, typeid(U)))
                return ret;
        }

        assert(0, "cannot cast from '" ~ (empty ? "<empty>" : type.toString()) ~ "' to '" ~ T.stringof ~ "'");
    }

    @property TypeInfo type() const
    {
        assert(!empty, "box cannot be empty");
        TypeInfo ti;
        _fptr(cast(Storage*)&_store, Operation.Type, &ti, null);
        return ti;
    }

    @property inout(void*) ptr() inout
    {
        assert(!empty, "box cannot be empty");
        void* ptr;
        _fptr(cast(Storage*)&_store, Operation.Pointer, &ptr, null);
        return cast(inout(void*))ptr;
    }

    void clear() {
        _fptr(cast(Storage*)&_store, Operation.Clear, null, null);
        _fptr = &fun!void;
    }

    @property bool empty() const {
        return _fptr == &fun!void;
    }

private:
    enum Operation : int
    {
        Type,
        Write,
        Read,
        Clear,
        Pointer,
        Destruct,
        Copy,
    }

    enum ScalarType : int {
        Bool, Byte, Ubyte, Short, Ushort, Int, Uint, Long, Ulong, Float, Double, Real, Char, Wchar, Dchar
    }

    alias ScalarTypes = AliasSeq!(bool, byte, ubyte, short, ushort, int, uint, long, ulong, float, double, real, char, wchar, dchar);

    template isSupportedScalarType(T) {
        enum isSupportedScalarType = staticIndexOf!(T, ScalarTypes) >= 0;
    }

    template isSupportedType(T)
    {
        enum isSupportedType =
            is(T == typeof(null)) ||
            is(T == class) ||
            is(T == interface) ||
            is(T == struct) ||
            is(T == enum) ||
            isSupportedScalarType!T ||
            isArray!T ||
            isPointer!T ||
            is(T == function) ||
            is(T == delegate);
    }

    enum StorageSize = Largest!(typeof(null), Object, void*, void[], void delegate(), long, real, float[4]).sizeof;

    union Storage
    {
        ubyte[StorageSize] buffer = void;
        void*[StorageSize / (void*).sizeof] ptrs;
    }

    private Storage _store;
    private bool function(Storage* store, uint opAndFlags, void* param, TypeInfo ti) _fptr = &fun!void;

    static bool fun(T : void)(Storage* store, uint opAndFlags, void* param, TypeInfo ti) {
        return false;
    }

    static bool fun(T)(Storage* store, uint opAndFlags, void* param, TypeInfo ti)
    {
        import core.memory : GC;
        import core.stdc.stdlib : malloc, free;
        import core.stdc.string : memcpy;

        Operation op = cast(Operation)(opAndFlags & 0xFFFFu);

        final switch(op)
        {
            case Operation.Write:
                static if(T.sizeof <= StorageSize)
                {
                    store.buffer[0..T.sizeof] = (cast(ubyte*)param)[0..T.sizeof];
                    store.buffer[T.sizeof..$] = 0;

                    static if(hasElaborateCopyConstructor!T)
                        typeid(T).postblit(cast(T*)store.buffer.ptr);

                    return true;
                }
                else
                {
                    T* cpy = cast(T*)malloc(T.sizeof);
                    memcpy(cpy, param, T.sizeof);

                    static if(hasIndirections!T)
                        GC.addRange(cpy, T.sizeof);

                    static if(hasElaborateCopyConstructor!T)
                        typeid(T).postblit(cpy);

                    *cast(T**)store.buffer.ptr = cpy;
                    store.buffer[(T*).sizeof..$] = 0;
                    return true;
                }
            case Operation.Read:
                static if(is(T == class) || is(T == interface))
                {
                    if(ti == typeid(Object))
                    {
                        T obj = *cast(T*)store.buffer.ptr;
                        *cast(Object*)param = cast(Object)obj;
                        return true;
                    }
                }
                else static if(isArray!T)
                {
                    if(ti == typeid(void[]))
                    {
                        T ary = *cast(T*)store.buffer.ptr;
                        *cast(void[]*)param = cast(void[])ary;
                        return true;
                    }
                }
                else static if(isPointer!T)
                {
                    if(ti == typeid(void*))
                    {
                        T ptr = *cast(T*)store.buffer.ptr;
                        *cast(void**)param = cast(void*)ptr;
                        return true;
                    }
                }
                else static if(isSupportedScalarType!T)
                {
                    ScalarType sc = cast(ScalarType)(opAndFlags >> 16);
                    if(sc != 0)
                    {
                        T val = *cast(T*)store.buffer.ptr;

                        final switch(sc) {
                            case ScalarType.Bool:   *cast(bool*)param   = cast(bool)val; break;
                            case ScalarType.Byte:   *cast(byte*)param   = cast(byte)val; break;
                            case ScalarType.Ubyte:  *cast(ubyte*)param  = cast(ubyte)val; break;
                            case ScalarType.Short:  *cast(short*)param  = cast(short)val; break;
                            case ScalarType.Ushort: *cast(ushort*)param = cast(ushort)val; break;
                            case ScalarType.Int:    *cast(int*)param    = cast(int)val; break;
                            case ScalarType.Uint:   *cast(uint*)param   = cast(uint)val; break;
                            case ScalarType.Long:   *cast(long*)param   = cast(long)val; break;
                            case ScalarType.Ulong:  *cast(ulong*)param  = cast(ulong)val; break;
                            case ScalarType.Float:  *cast(float*)param  = cast(float)val; break;
                            case ScalarType.Double: *cast(double*)param = cast(double)val; break;
                            case ScalarType.Real:   *cast(real*)param   = cast(real)val; break;
                            case ScalarType.Char:   *cast(char*)param   = cast(char)val; break;
                            case ScalarType.Wchar:  *cast(wchar*)param  = cast(wchar)val; break;
                            case ScalarType.Dchar:  *cast(dchar*)param  = cast(dchar)val; break;
                        }

                        return true;
                    }
                }
                else
                {
                    static if(T.sizeof <= StorageSize)
                    {
                        if(ti == typeid(T)) {
                            *cast(T*)param = *cast(T*)store.buffer.ptr;
                            return true;
                        }
                    }
                    else
                    {
                        if(ti == typeid(T)) {
                            *cast(T*)param = **cast(T**)store.buffer.ptr;
                            return true;
                        }
                    }
                }
                break;

            case Operation.Clear:
                store.buffer[0..$] = 0;
                break;

            case Operation.Type:
                static if(is(T == class) || is(T == interface)) {
                    *cast(TypeInfo*)param = typeid(*cast(T*)store.buffer.ptr);
                }
                else {
                    *cast(TypeInfo*)param = typeid(T);
                }
                break;

            case Operation.Pointer:
                static if(T.sizeof <= StorageSize)
                {
                    *cast(void**)param = cast(void*)store.buffer.ptr;
                    return true;
                }
                else
                {
                    *cast(void**)param = *cast(void**)store.buffer.ptr;
                    return true;
                }

            case Operation.Destruct:
                static if(T.sizeof > StorageSize)
                {
                    T* p = *cast(T**)store.buffer.ptr;
                    store.buffer[0..(T*).sizeof] = 0;

                    static if(hasElaborateDestructor!T)
                        typeid(T).destroy(p);

                    static if(hasIndirections!T)
                        GC.removeRange(p);

                    free(p);
                }
                else
                {
                    static if(hasElaborateDestructor!T)
                        typeid(T).destroy(cast(T*)store.buffer.ptr);
                }
                break;

            case Operation.Copy:
                Storage* from = cast(Storage*)param;
                T* p = null;

                static if(T.sizeof > StorageSize)
                {
                    p = cast(T*)malloc(T.sizeof);
                    memcpy(p, *cast(T**)from.buffer.ptr, T.sizeof);
                    static if(hasIndirections!T) GC.addRange(p, T.sizeof);
                    *cast(T**)store.buffer.ptr = p;
                    store.buffer[(T*).sizeof..$] = 0;
                }
                else
                {
                    p = cast(T*)store.buffer.ptr;
                    if(store != from) memcpy(p, cast(T*)from.buffer.ptr, T.sizeof);
                }

                static if(hasElaborateCopyConstructor!T)
                    typeid(T).postblit(p);

                break;
        }

        return false;
    }
}

template UnqualR(T)
{
    template Next(S)
    {
        import std.traits : PointerTarget;

        template ArrayElementType(T : T[]) {
            alias ArrayElementType = T;
        }

        static if(isArray!S)
            alias Next = UnqualR!(ArrayElementType!S)[];
        else static if(isPointer!S)
            alias Next = UnqualR!(PointerTarget!S)*;
        else
            alias Next = S;
    }

    static if      (is(T U ==          immutable U)) alias UnqualR = Next!U;
    else static if (is(T U == shared inout const U)) alias UnqualR = Next!U;
    else static if (is(T U == shared inout       U)) alias UnqualR = Next!U;
    else static if (is(T U == shared       const U)) alias UnqualR = Next!U;
    else static if (is(T U == shared             U)) alias UnqualR = Next!U;
    else static if (is(T U ==        inout const U)) alias UnqualR = Next!U;
    else static if (is(T U ==        inout       U)) alias UnqualR = Next!U;
    else static if (is(T U ==              const U)) alias UnqualR = Next!U;
    else                                             alias UnqualR = Next!T;
}

unittest
{
    import std.math : approxEqual;

    class A {
        int a = 123;
    }

    struct V4 {
        float x, y, z, w;
    }

    struct RV4 {
        real x, y, z, w;
    }

    Box box;

    box = 123;
    assert(box.type == typeid(int));
    assert(cast(int)box == 123);
    assert(approxEqual(cast(float)box, 123.0f, 0.001f));
    assert(cast(long)box == 123);

    box = 4.56;
    assert(box.type == typeid(double));
    assert(approxEqual(cast(double)box, 4.56));
    assert(approxEqual(cast(real)box, 4.56));
    assert(cast(int)box == 4);

    auto a = new A();
    box = a;
    assert(box.type == typeid(A));
    assert(cast(Object)box == a);
    assert(cast(A)box == a);

    box = cast(Object)a;
    assert(box.type == typeid(A));
    assert(cast(Object)box == a);
    assert(cast(A)box == a);

    box = V4(1, 2, 3, 4);
    assert(box.type == typeid(V4));
    assert(cast(V4)box == V4(1, 2, 3, 4));

    box = RV4(1, 2, 3, 4);
    assert(box.type == typeid(RV4));
    assert(cast(RV4)box == RV4(1, 2, 3, 4));

    box = [1, 2, 3];
    assert(box.type == typeid(int[]));
    assert(cast(int[])box == [1, 2, 3]);

    box = cast(const(int[]))[4, 5, 6];
    assert(box.type == typeid(int[]));
    assert(cast(int[])box == [4, 5, 6]);

    box = new int(123);
    assert(box.type == typeid(int*));
    assert(*cast(int*)box == 123);

    box = new const(int)(123);
    assert(box.type == typeid(int*));
    assert(*cast(int*)box == 123);

    Box box1 = 1234;
    Box box2 = box1;
    assert(box2.type == typeid(int));
    assert(cast(int)box2 == 1234);
    box2 = 0.5f;
    assert(box2.type == typeid(float));
    assert(approxEqual(cast(float)box2, 0.5f));
    box1 = box2;
    assert(box1.type == typeid(float));
    assert(approxEqual(cast(float)box1, 0.5f, 0.001f));

    box1 = RV4(1, 2, 3, 4);
    box2 = box1;
    assert(cast(RV4)box2 == RV4(1, 2, 3, 4));

    void function() x = { };
    int delegate(int) y = z => z;
    box1 = x;
    box2 = y;
    assert(cast(void function())box1 == x);
    assert(cast(int delegate(int))box2 == y);
}

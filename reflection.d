module reflection;
import box;
import core.vararg;
import std.conv;
import std.format;
import std.functional;
import std.meta;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;
import std.uni;
import std.meta;

enum SymbolType
{
    Unsupported,
    Module,
    Interface,
    Class,
    Struct,
    Union,
    Enum,
    Constant,
    Scalar,
    Field,
    Method,
    Property,
}

enum Protection
{
    Private,
    Protected,
    Package,
    Public,
    Export,
}

// attribute that specifies that a symbol should not be reflected
struct NoReflection {}

abstract class Reflection
{
    @property string name() const;
    @property SymbolType symbolType() const;
    @property TypeInfo typeId() const;
    override string toString() const;
}

final class Unsupported : Reflection
{
    private TypeInfo _type;
    private string _name;

    private this(TypeInfo type, string name) {
        _type = type;
        _name = name;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Unsupported;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    override string toString() const {
        return _name;
    }
}

abstract class Scope : Reflection
{
    protected const(Interface)[] _interfaces;
    protected const(Class)[] _classes;
    protected const(Struct)[] _structs;
    protected const(Enum)[] _enums;
    protected const(Property)[] _properties;
    protected const(Field)[] _fields;
    protected const(Method)[] _methods;

    final @property const(Interface)[] interfaces() const {
        return _interfaces;
    }

    final @property const(Class)[] classes() const {
        return _classes;
    }

    final @property const(Struct)[] structs() const {
        return _structs;
    }

    final @property const(Enum)[] enums() const {
        return _enums;
    }

    final @property const(Field)[] fields() const {
        return _fields;
    }

    final @property const(Property)[] properties() const {
        return _properties;
    }

    final @property const(Method)[] methods() const {
        return _methods;
    }

    final const(Interface) getInterface(string name) const {
        return findByName(_interfaces, name);
    }

    final const(Class) getClass(string name) const {
        return findByName(_classes, name);
    }

    final const(Struct) getStruct(string name) const {
        return findByName(_structs, name);
    }

    final const(Enum) getEnum(string name) const {
        return findByName(_enums, name);
    }

    final const(Accessor) getAccessor(string name) const {
        auto field = findByName(_fields, name);
        return field ? field : findByName(_properties, name);
    }

    final const(Field) getField(string name) const {
        return findByName(_fields, name);
    }

    final const(Property) getProperty(string name) const {
        return findByName(_properties, name);
    }

    final const(Method) getMethod(string name) const {
        return findByName(_methods, name);
    }

    final const(Method)[] getMethods(string name) const {
        return findAllByName(_methods, name);
    }
}

final class Module : Scope
{
    private string _name;

    private this(string name) {
        _name = name;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Module;
    }

    @property override TypeInfo typeId() const {
        return null;
    }

    override string toString() const {
        return "module " ~ _name;
    }
}

final class Interface : Scope
{
    private string _name;
    private TypeInfo _type;
    private Protection _prot;
    private const(Interface)[] _bases;

    private this(
        string name,
        TypeInfo type,
        Protection prot,
        const(Interface)[] bases)
    {
        _name = name;
        _type = type;
        _prot = prot;
        _bases = bases;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Interface;
    }

    override string toString() const {
        return toLower(to!string(_prot)) ~ " interface " ~ _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property const(Interface[]) bases() const {
        return _bases;
    }
}

final class Class : Scope
{
    private string _name;
    private TypeInfo _type;
    private Protection _prot;
    private const(Class) _base;
    private const(Interface)[] _itfs;
    private Object function() _instantiator;

    private this(
        string name,
        TypeInfo type,
        Protection prot,
        const(Class) base,
        const(Interface)[] itfs,
        Object function() instantiator)
    {
        _name = name;
        _type = type;
        _prot = prot;
        _base = base;
        _itfs = itfs;
        _instantiator = instantiator;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Class;
    }

    override string toString() const {
        return toLower(to!string(_prot)) ~ " class " ~ _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property const(Class) base() const {
        return _base;
    }

    @property const(Interface[]) implementedInterfaces() const {
        return _itfs;
    }

    Object createInstance() const {
        return _instantiator();
    }
}

final class Struct : Scope
{
    private string _name;
    private TypeInfo _type;
    private Protection _prot;
    private SymbolType _symbolType;
    private string _symbolTypeName;

    private this(
        string name,
        TypeInfo type,
        Protection prot,
        SymbolType symbolType)
    {
        _name = name;
        _type = type;
        _prot = prot;
        _symbolType = symbolType;
        _symbolTypeName = _symbolType == SymbolType.Struct ? "struct" : "union";
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return _symbolType;
    }

    override string toString() const {
        return toLower(to!string(_prot)) ~ " " ~ _symbolTypeName ~ " " ~ _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }
}

final class Enum : Reflection
{
    private string _name;
    private TypeInfo _type;
    private Protection _prot;
    private const(Constant)[] _members;

    private this(
        string name,
        TypeInfo type,
        Protection prot,
        const(Constant)[] members)
    {
        _name = name;
        _type = type;
        _prot = prot;
        _members = members;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Enum;
    }

    override string toString() const {
        return toLower(to!string(_prot)) ~ " enum " ~ _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property const(Constant)[] members() const {
        return _members;
    }

    const(Constant) getMember(string name) const {
        return findByName(_members, name);
    }
}

final class Constant : Reflection
{
    private string _name;
    private TypeInfo _type;
    private Protection _prot;
    private Box function() _getter;
    private string _otype;

    private this(
        string name,
        TypeInfo type,
        Protection prot,
        Box function() getter,
        string otype)
    {
        _name = name;
        _type = type;
        _prot = prot;
        _getter = getter;
        _otype = otype;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Constant;
    }

    override string toString() const {
        return toLower(to!string(_prot)) ~ " " ~ _name ~ " " ~ _otype;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property Box value() const {
        return _getter();
    }
}

final class Scalar : Reflection
{
    private string _name;
    private TypeInfo _type;
    private Box function(void* ptr) _getter;
    private void function(void* ptr, ref Box value) _setter;

    private this(
        string name,
        TypeInfo type,
        Box function(void* ptr) getter,
        void function(void* ptr, ref Box value) setter)
    {
        _name = name;
        _type = type;
        _getter = getter;
        _setter = setter;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Scalar;
    }

    override string toString() const {
        return _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    Box get(void* ptr) const {
        return _getter(ptr);
    }

    void set(void* ptr, Box value) const {
        _setter(ptr, value);
    }
}

abstract class Accessor : Reflection
{
    protected Box getBoxedValue(ref Box target) const;
    protected void setBoxedValue(ref Box target, ref Box value) const;
    @property bool canGetValue() const;
    @property bool canSetValue() const;
    @property const(Reflection) getterReturnType() const;
    @property const(Reflection) setterParameterType() const;

    Box getValue(Target)(auto ref Target target) const
    {
        static if(is(Target == Box)) {
            return _getValue(target);
        }
        else static if(is(Target == struct)) {
            Box tar = &target;
            return _getValue(tar);
        }
        else static if(is(Target == typeof(null)) ||
                       is(Target == class) ||
                           is(Target == interface) ||
                               (isPointer!Target && is(PointerTarget!Target == struct)))
        {
            Box tar = target;
            return _getValue(tar);
        }
        else
        {
            static assert(0, "invalid accessor target '" ~ Target.stringof ~ "' - " ~
                          "target must be a class, interface, struct, struct*, null, " ~
                          "or a Box containing one of those types");
        }
    }

    void setValue(Target, Value)(auto ref Target target, auto ref Value value) const
    {
        Box val = value;

        static if(is(Target == Box)) {
            _setValue(target, val);
        }
        else static if(is(Target == struct)) {
            Box tar = &target;
            _setValue(tar, val);
        }
        else static if(is(Target == typeof(null)) ||
                       is(Target == class) ||
                           is(Target == interface) ||
                               (isPointer!Target && is(PointerTarget!Target == struct)))
        {
            Box tar = target;
            _setValue(tar, val);
        }
        else
        {
            static assert(0, "invalid field target '" ~ Target.stringof ~ "' - " ~
                          "target must be a class, interface, struct, struct*, null, " ~
                          "or a Box containing one of those types");
        }
    }
}

final class Field : Accessor
{
    enum Operation
    {
        Get,
        Set,
        Address,
    }

    private alias Operator = void function(ref Box target, Box* value, Operation operation);

    private string _name;
    private string _typeName;
    private TypeInfo _type;
    private Protection _prot;
    private string _fieldTypeName;
    private size_t _offset;
    private bool _isStatic;
    private Operator _operator;

    private this(
        string name,
        string typeName,
        TypeInfo type,
        Protection prot,
        string fieldTypeName,
        size_t offset,
        bool isStatic,
        Operator operator)
    {
        _name = name;
        _typeName = typeName;
        _type = type;
        _prot = prot;
        _fieldTypeName = fieldTypeName;
        _offset = offset;
        _isStatic = isStatic;
        _operator = operator;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Field;
    }

    override string toString() const {
        string _static = _isStatic ? "static " : "";
        return toLower(to!string(_prot)) ~ " " ~ _static ~ _typeName ~ " " ~ _name;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property bool isStatic() const {
        return _isStatic;
    }

    protected override Box getBoxedValue(ref Box target) const {
        Box ret;
        _operator(target, &ret, Operation.Get);
        return ret;
    }

    protected override void setBoxedValue(ref Box target, ref Box value) const {
        _operator(target, &value, Operation.Set);
    }

    @property override bool canGetValue() const {
        return true;
    }

    @property override bool canSetValue() const {
        return true;
    }

    @property override const(Reflection) getterReturnType() const {
        return reflect(_fieldTypeName);
    }

    @property override const(Reflection) setterParameterType() const {
        return reflect(_fieldTypeName);
    }

    const(Reflection) fieldType() const {
        return reflect(_fieldTypeName);
    }

    size_t offset() const {
        return _offset;
    }
}

final class Method : Reflection
{
    static struct InvokeParams
    {
        TypeInfo[] argTypes;
        void*[] args;
    }

    alias Invoker = Box function(ref Box target, ref InvokeParams params);

    private string _name;
    private TypeInfo _type;
    private string _returnTypeName;
    private Protection _prot;
    private bool _isStatic;
    private bool _isFinal;
    private bool _isOverride;
    private bool _isProperty;
    private bool _isCallable;
    private string[] _paramTypeNames;
    private string[] _paramNames;
    private Invoker _invoker;

    private this(
        string name,
        TypeInfo type,
        string returnTypeName,
        string[] paramTypeNames,
        string[] paramNames,
        Protection prot,
        bool isStatic,
        bool isFinal,
        bool isOverride,
        bool isProperty,
        bool isCallable,
        Invoker invoker)
    {
        _name = name;
        _type = type;
        _returnTypeName = returnTypeName;
        _paramTypeNames = paramTypeNames;
        _paramNames = paramNames;
        _prot = prot;
        _isStatic = isStatic;
        _isFinal = isFinal;
        _isOverride = isOverride;
        _isProperty = isProperty;
        _isCallable = isCallable;
        _invoker = invoker;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Method;
    }

    override string toString() const
    {
        string _property = _isProperty ? "@property " : "";
        string prot = to!string(_prot) ~ " ";
        string _static = _isStatic ? "static " : "";
        string _final = _isFinal ? "final " : "";
        string _override = _isOverride ? "override " : "";

        string ret = _property ~ toLower(prot) ~ _static ~ _final ~ _override ~ _returnTypeName ~ " " ~ _name;

        ret ~= "(";

        foreach(i, tname; _paramTypeNames)
        {
            if(i > 0) ret ~= ", ";
            ret ~= tname ~ " " ~ _paramNames[i];
        }

        ret ~= ")";

        return ret;
    }

    @property override TypeInfo typeId() const {
        return cast(TypeInfo)_type;
    }

    @property Protection protection() const {
        return _prot;
    }

    @property bool isStatic() const {
        return isStatic;
    }

    @property bool isFinal() const {
        return _isFinal;
    }

    @property bool isOverride() const {
        return _isOverride;
    }

    @property bool isProperty() const {
        return _isProperty;
    }

    @property const(Reflection) returnType() const {
        return reflect(_returnTypeName);
    }

    @property ReflectionRange parameterTypes() const {
        return ReflectionRange(cast(string[])_paramTypeNames);
    }

    @property string[] parameterNames() const {
        return cast(string[])_paramNames;
    }

    @property bool isCallable() const {
        return _isCallable;
    }

    Box invoke(Target, Args...)(auto ref Target target, auto ref Args args) const
    {
        InvokeParams params;

        static if(Args.length > 0)
        {
            import core.stdc.stdlib : alloca;

            auto argSz = Args.length * TypeInfo.sizeof;
            auto ptrSz = Args.length * (void*).sizeof;
            params.argTypes = cast(TypeInfo[])alloca(argSz)[0..argSz];
            params.args = cast(void*[])alloca(ptrSz)[0..ptrSz];

            foreach(i, ArgType; Args) {
                static if(is(ArgType == Box)) {
                    params.argTypes[i] = args[i].type;
                    params.args[i] = args[i].ptr;
                }
                else {
                    params.argTypes[i] = typeid(ArgType);
                    params.args[i] = &args[i];
                }
            }
        }

        static if(is(Target == Box)) {
            return _invoker(target, params);
        }
        else static if(is(Target == struct)) {
            Box tar = &target;
            return _invoker(tar, params);
        }
        else static if(is(Target == typeof(null)) ||
                       is(Target == class) ||
                       is(Target == interface) ||
                       (isPointer!Target && is(PointerTarget!Target == struct)))
        {
            Box tar = target;
            return _invoker(tar, params);
        }
        else
        {
            static assert(0, "invalid invocation target '" ~ Target.stringof ~ "' - " ~
                          "target must be a class, interface, struct, struct*, null, " ~
                          "or a Box containing one of those types");
        }
    }
}

final class Property : Accessor
{
    private string _name;
    private const(Method)[] _getters;
    private const(Method)[] _setters;

    this(string name, const(Method)[] getters, const(Method)[] setters)
    {
        _name = name;
        _getters = getters;
        _setters = setters;
    }

    @property override string name() const {
        return _name;
    }

    @property override SymbolType symbolType() const {
        return SymbolType.Property;
    }

    @property override TypeInfo typeId() const {
        return typeid(void);
    }

    const(Method)[] getters() const {
        return _getters;
    }

    const(Method)[] setters() const {
        return _setters;
    }

    @property const(Reflection) returnType() const {
        assert(_getters.length);
        return _getters[0].returnType;
    }

    @property const(Reflection) paramType() const {
        assert(_setters.length);
        return _setters[0].parameterTypes.front;
    }

    protected override Box getBoxedValue(ref Box target) const {
        assert(_getters.length);
        return _getters[0].invoke(target);
    }

    protected override void setBoxedValue(ref Box target, ref Box value) const {
        assert(_setters.length);
        _setters[0].invoke(target, value);
    }

    @property override bool canGetValue() const {
        return _getters.length != 0;
    }

    @property override bool canSetValue() const {
        return _setters.length != 0;
    }

    @property override const(Reflection) getterReturnType() const {
        assert(_getters.length);
        return _getters[0].returnType();
    }

    @property override const(Reflection) setterParameterType() const {
        assert(_setters.length);
        return _setters[0].parameterTypes.front;
    }

    override string toString() const {
        auto getStr = canGetValue() ? "get" : "";
        auto setStr = canSetValue() ? (canGetValue() ? ", " : "") ~ "set" : "";
        return "@property " ~ _name ~ "(" ~ getStr ~ setStr ~ ")";
    }
}

struct ReflectionRange
{
    private string[] _typeNames;
    private Rebindable!(const Reflection) _current;

    private this(string[] typeNames)
    {
        _typeNames = typeNames;
        if(_typeNames.length)
            _current = reflect(_typeNames[0]);
    }

    bool empty() const {
        return _typeNames.length == 0;
    }

    const(Reflection) front() const {
        assert(!empty);
        return _current;
    }

    void popFront() {
        assert(!empty);
        _typeNames = _typeNames[1..$];
        if(_typeNames.length) _current = reflect(_typeNames[0]);
    }
}

const(Module) reflect(alias T)() if(isModule!T) {
    return Reflector!T.get();
}

const(Interface) reflect(alias T)() if(is(T == interface) && !__traits(isTemplate, T)) {
    return Reflector!(Unqual!T).get();
}

const(Class) reflect(alias T)() if(is(T == class) && !__traits(isTemplate, T)) {
    return Reflector!(Unqual!T).get();
}

const(Struct) reflect(alias T)() if((is(T == struct) || is(T == union)) && !__traits(isTemplate, T)) {
    return Reflector!(Unqual!T).get();
}

const(Enum) reflect(alias T)() if(is(T == enum) && !__traits(isTemplate, T)) {
    return Reflector!(Unqual!T).get();
}

const(Scalar) reflect(T)() if(isScalarType!T && !__traits(isTemplate, T)) {
    return Reflector!(Unqual!T).get();
}

const(Method) reflect(alias T)() if(isSomeFunction!T && !isReservedMethod!T && !__traits(isTemplate, T)) {
    return Reflector!T.get();
}

const(Unsupported) reflect(T)()
    if(__traits(isTemplate, T) || isDelegate!T || isArray!T || isPointer!T ||
       !(isScalarType!T || isModule!T || is(T == interface) || is(T == class) || is(T == struct) || is(T == union) || is(T == enum))
    )
{
    static const(Unsupported) refl = new Unsupported(typeid(T), T.stringof);
    return refl;
}

const(Reflection) reflect(string qualifiedName) {
    assert(!__ctfe, "this method cannot be called at compile time");
    auto r = qualifiedName in _reflections;
    return r ? *r : null;
}

private:

Rebindable!(const(Reflection))[string] _reflections;

final class Reflector(T) if(isScalarType!T)
{
    static this() {
        _reflections[fullyQualifiedName!T] = get();
    }

    static auto get()
    {
        static Box getter(void* ptr) {
            return Box(*cast(T*)ptr);
        }

        static void setter(void* ptr, ref Box value) {
            static if(isSetSupported!T)
                *(cast(T*)ptr) = cast(T)value;
            else
                assert(0);
        }

        static const(Scalar) refl = new Scalar(T.stringof, typeid(T), &getter, &setter);
        return refl;
    }
}

final class Reflector(alias T)
{
    static this()
    {
        static if(isModule!T || isSomeFunction!T)
            _reflections[fullyQualifiedName!T] = get();
        else
            _reflections[fullyQualifiedName!(Unqual!T)] = get();
    }

    static auto get()
    {
        static if(isModule!T)
        {
            static const(Module) refl = parseScope!T(new Module(T.stringof[7..$]));
        }
        else static if(is(T == interface))
        {
            static const(Interface) refl = parseScope!T(new Interface(__traits(identifier, T), typeid(T), protectionOf!T, baseInterfaces!T));
        }
        else static if(is(T == class))
        {
            static Object instantiator()
            {
                enum canInstantiate = __traits(compiles, { auto x = new T; });
                static if(canInstantiate) return new T;
                else return null;
            }

            static const(Class) refl = parseScope!T(new Class(__traits(identifier, T), typeid(T), protectionOf!T, baseclassOf!T, baseInterfaces!T, &instantiator));
        }
        else static if(is(T == struct) || is(T == union))
        {
            static const(Struct) refl = parseScope!T(new Struct(__traits(identifier, T), typeid(T), protectionOf!T, is(T == struct) ? SymbolType.Struct : SymbolType.Union));
        }
        else static if(is(T == enum))
        {
            static const(Enum) refl = parseScope!T(new Enum(T.stringof, typeid(T), protectionOf!T, enumMembers!T));
        }
        else static if(isDelegate!T)
        {
            
        }
        else static if(isFunctionPointer!T)
        {
            
        }
        else static if(isSomeFunction!T && !isReservedMethod!T)
        {
            alias SCOPE = Alias!(__traits(parent, T));

            static if(isAbstractClass!SCOPE || isAbstractFunction!T)
                enum isCallable = false;
            else
                enum isCallable = true;

            static Box invoker(ref Box target, ref Method.InvokeParams params)
            {
                alias RT = ReturnType!(typeof(&T));

                static if(isAbstractClass!SCOPE) {
                    throw new Exception("cannot call methods of abstract class");
                }
                else static if(isAbstractFunction!T) {
                    throw new Exception("cannot call abstract methods");
                }
                else static if(is(RT S == inout S) || is(RT S == inout S[])) {
                    throw new Exception("cannot call inout function");
                }
                else
                {
                    static if(isAggregateType!SCOPE)
                    {
                        static if(is(SCOPE == class) || is(SCOPE == interface)) {
                            SCOPE tar = cast(SCOPE)target;
                        }
                        else static if(is(SCOPE == struct)) {
                            bool isPtr = (target.type == typeid(SCOPE*));
                            SCOPE* tar = isPtr ? cast(SCOPE*)target : cast(SCOPE*)target.ptr;
                        }
                        else {
                            static assert(0, "instance type must be a class, interface, or struct*");
                        }

                        static if(__traits(isStaticFunction, T))
                        {
                            if(tar !is null)
                                throw new Exception("instance pointer should be null");
                        }
                        else
                        {
                            if(tar is null) {
                                throw new Exception("instance pointer cannot be null");
                            }
                        }
                    }

                    alias ParamTypes = ParameterTypeTuple!(typeof(&T));
                    alias ArgTypes = UnqualTuple!ParamTypes;

                    if(params.args.length != ParamTypes.length)
                        throw new Exception("wrong number of arguments");
                    
                    foreach(i, PType; ParamTypes)
                    {
                        if(params.argTypes[i] != typeid(PType))
                            throw new Exception("wrong argument type - expected '" ~ PType.stringof ~ "', received '" ~ params.argTypes[i].toString() ~ "'.");
                    }

                    ArgTypes args;

                    foreach(i, AType; ArgTypes)
                        args[i] = *cast(AType*)params.args[i];
                    
                    alias MethodTypeOf!T MethodType;

                    MethodType fun;

                    static if(isDelegate!MethodType)
                    {
                        fun.funcptr = cast(typeof(fun.funcptr))&T;
                        fun.ptr = cast(void*)tar;
                    }
                    else
                    {
                        fun = &T;
                    }

                    static if(__traits(compiles, Box(fun(args))))
                    {
                        return Box(fun(args));
                    }
                    else
                    {
                        fun(args);
                        return Box();
                    }
                }
            }

            static const(Method) refl = new Method(
                 __traits(identifier, T),
                 typeid(typeof(&T)),
                 fullyQualifiedName!(ReturnType!T),
                 paramTypeNames!T,
                 [ParameterIdentifierTuple!T],
                 protectionOf!T,
                 __traits(isStaticFunction, T),
                 __traits(isFinalFunction, T),
                 __traits(isOverrideFunction, T),
                 (functionAttributes!(T) & FunctionAttribute.property) != 0,
                 isCallable,
                 &invoker);
        }
        else
        {
            static assert("cannot reflect type '" ~ T.stringof ~ "'");
        }

        return refl;
    }
}

string[] paramTypeNames(alias T)()
{
    alias Types = ParameterTypeTuple!(typeof(&T));
    string[] ret = new string[Types.length];
    foreach(i, Ty; Types) ret[i] = fullyQualifiedName!Ty;
    return ret;
}

template isGetSupported(T) {
    enum isGetSupported = __traits(compiles, { Box(T.init); });
}

template isSetSupported(T) {
	import std.traits : isNumeric, isBoolean, isSomeString;
	enum isSetSupported = isNumeric!T || isBoolean!T || is(T : Object) || isSomeString!T;
}

const(Constant)[] enumMembers(T)()
{
    alias allMembers = AliasSeq!(__traits(allMembers, T));
    auto ret = new Constant[allMembers.length];

    foreach(i, member; allMembers)
    {
        static if(__traits(hasMember, T, member))
        {
            alias M = Alias!(__traits(getMember, T, member));
            alias OriginalType!(typeof(M)) OT;
            Box function() getter = { return Box(cast(OT)M); };
            ret[i] = new Constant(__traits(identifier, M), typeid(M), protectionOf!M, getter, to!string(cast(OT)M));
        }
    }
    return ret;
}

template isScalar(T) {
    import std.traits : isScalarType;
    enum isScalar = isScalarType!T;
}

template isScalar(alias T) {
    enum isScalar = false;
}

template isScalar(string fqn)
{
    import std.traits : isScalarType;
    static if(__traits(compiles, { mixin("enum e = isScalarType!(" ~ fqn ~ ");"); }))
        mixin("enum isScalar = isScalarType!(" ~ fqn ~ ");");
    else
        enum isScalar = false;
}

const(Interface)[] baseInterfaces(T)()
{
    alias Itfs = InterfacesTuple!T;
    Interface[] ret = new Interface[Itfs.length];
    foreach(i, Itf; Itfs)
        ret[i] = reflect!Itf;
    return ret;
}

template MethodTypeOf(alias M)
{
    static if(__traits(isStaticFunction, M))
        alias MethodTypeOf = typeof(toDelegate(&M).funcptr);
    else
        alias MethodTypeOf = typeof(toDelegate(&M));
}

template owningModule(alias T)
{
    alias parent = Alias!(__traits(parent, T));

    static if(isModule!parent)
        alias owningModule = parent;
    else
        alias owningModule = owningModule!parent;
}

template isModule(alias T) {
    enum isModule = __traits(isModule, T);
}

template isField(alias T)
{
    enum hasInit = is(typeof(typeof(T).init));
    enum isManifestConst = __traits(compiles, { enum e = T; });
    enum isField = hasInit && !isManifestConst;
}

T findByName(T)(T[] arr, string name)
{
    foreach(e; arr) {
        if(e.name == name)
            return e;
    }

    return null;
}

T[] findAllByName(T)(T[] arr, string name)
{
    T[] ret;

    foreach(e; arr) {
        if(e.name == name)
            ret ~= e;
    }

    return ret;
}

private template toProtection(string prot)
{
    static if(prot == "public")
        enum toProtection = Protection.Public;
    else static if(prot == "protected")
        enum toProtection = Protection.Protected;
    else static if(prot == "private")
        enum toProtection = Protection.Private;
    else static if(prot == "package")
        enum toProtection = Protection.Package;
    else static if(prot == "export")
        enum toProtection = Protection.Export;
}

private template protectionOf(alias T)
{
    enum prot = __traits(getProtection, T);
    enum protectionOf = toProtection!prot;
}

const(Class) baseclassOf(alias T)()
{
    static if(!is(T == Object))
    {
        alias BaseClassesTuple!T B;
        return reflect!(B[0]);
    }
    else
    {
        return null;
    }
}

private template UnqualTuple(Args...)
{
    static if(Args.length > 1)
        alias UnqualTuple = AliasSeq!(Unqual!(Args[0]), UnqualTuple!(Args[1..$]));
    else static if(Args.length > 0)
        alias UnqualTuple = AliasSeq!(Unqual!(Args[0]));
    else
        alias UnqualTuple = AliasSeq!();
}

template isReservedMethod(alias M)
{
    enum id = __traits(identifier, M);
    enum isReservedMethod = id.length >= 2 && id[0..2] == "__";
}

template isProperty(alias T) {
    enum isProperty = (functionAttributes!T & FunctionAttribute.property) != 0;
}

template isGetterProperty(alias T)
{
    static if(isProperty!T && !is(ReturnType!T == void) && (arity!T == 0))
        enum isGetterProperty = true;
    else
        enum isGetterProperty = false;
}

template isSetterProperty(alias T)
{
    static if(isProperty!T && is(ReturnType!T == void) && (arity!T == 1))
        enum isSetterProperty = true;
    else
        enum isSetterProperty = false;
}

TARGET parseScope(alias SCOPE, TARGET)(TARGET target)
{
    foreach(member; __traits(allMembers, SCOPE))
    {
        enum noReflection = hasUDA!(__traits(getMember, SCOPE, member), NoReflection);

        static if(!noReflection)
        {
            alias Alias!(__traits(getMember, SCOPE, member)) mem;

            static if(is(mem == interface)) {
                target._interfaces ~= reflect!(__traits(getMember, SCOPE, member))();
            }
            static if(is(mem == class)) {
                target._classes ~= reflect!(__traits(getMember, SCOPE, member))();
            }
            else static if(is(mem == struct) || is(mem == union)) {
                target._structs ~= reflect!(__traits(getMember, SCOPE, member))();
            }
            else static if(is(mem == enum)) {
                target._enums ~= reflect!(__traits(getMember, SCOPE, member));
            }
            else static if(isDelegate!(__traits(getMember, SCOPE, member))) {

            }
            else static if(isFunctionPointer!(__traits(getMember, SCOPE, member))) {

            }
            else static if(isSomeFunction!(__traits(getMember, SCOPE, member)) && !isReservedMethod!mem)
            {
                enum isProp = isProperty!mem;

                alias OverloadSeq = AliasSeq!(__traits(getOverloads, SCOPE, member));
                
                static if(isProp) {
                    alias AllGetters = Filter!(isGetterProperty, OverloadSeq);
                    alias AllSetters = Filter!(isSetterProperty, OverloadSeq);
                    Method[] getters = new Method[AllGetters.length];
                    Method[] setters = new Method[AllSetters.length];
                    size_t getterCount = 0;
                    size_t setterCount = 0;
                }
                else
                {
                    Method[] overloads = new Method[OverloadSeq.length];
                }

                foreach(i, Overload; OverloadSeq)
                {
                    Method method = cast(Method)reflect!Overload;

                    static if(isProp)
                    {
                        static if(isGetterProperty!Overload)
                            getters[getterCount++] = method;

                        static if(isSetterProperty!Overload)
                            setters[setterCount++] = method;
                    }
                    else
                    {
                        overloads[i] = method;
                    }
                }

                static if(isProp)
                    target._properties ~= new Property(member, cast(const(Method)[])getters, cast(const(Method)[])setters);
                else
                    target._methods ~= cast(const(Method)[])overloads;
            }
            else static if(isField!(__traits(getMember, SCOPE, member)))
            {
                alias FT = typeof(mem);

                static if(__traits(compiles, { enum _ = mem.offsetof; })) {
                    enum offset = mem.offsetof;
                    enum isStatic = false;
                }
                else {
                    enum offset = 0;
                    enum isStatic = true;
                }

                Field.Operator operator = (ref Box target, Box* value, Field.Operation operation)
                {
                    final switch(operation)
                    {
                        case Field.Operation.Set:
                            static if(isSetSupported!FT)
                            {
                                static if(isStatic) {
                                    mem = cast(FT)(*value);
                                }
                                else
                                {
                                    static if(is(SCOPE == class) || is(SCOPE == interface)) {
                                        SCOPE tar = cast(SCOPE)target;
                                    }
                                    else static if(is(SCOPE == struct)) {
                                        bool isPtr = (target.type == typeid(SCOPE*));
                                        SCOPE* tar = isPtr ? cast(SCOPE*)target : cast(SCOPE*)target.ptr;
                                    }
                                    else {
                                        static assert(0, "target instance must be a class, interface, or struct*");
                                    }

                                    *cast(FT*)(cast(void*)tar + offset) = cast(FT)*value;
                                }
                            }
                            else
                            {
                                writeln("setValue not supported for this field type");
                            }
                            break;
                        case Field.Operation.Get:
                            static if(isGetSupported!FT)
                            {
                                static if(isStatic) {
                                    *value = mem;
                                }
                                else
                                {
                                    static if(is(SCOPE == class) || is(SCOPE == interface)) {
                                        SCOPE tar = cast(SCOPE)target;
                                    }
                                    else static if(is(SCOPE == struct)) {
                                        bool isPtr = (target.type == typeid(SCOPE*));
                                        SCOPE* tar = isPtr ? cast(SCOPE*)target : cast(SCOPE*)target.ptr;
                                    }
                                    else {
                                        static assert(0, "instance type must be a class, interface, or struct*");
                                    }

                                    *value = *cast(FT*)(cast(void*)tar + offset);
                                }
                            }
                            else
                            {
                                writeln("setValue not supported for this field type");
                            }
                            break;
                        case Field.Operation.Address:
                            static if(isStatic) {
                                *value = cast(void*)(&mem);
                            }
                            else
                            {
                                static if(is(SCOPE == class) || is(SCOPE == interface)) {
                                    SCOPE tar = cast(SCOPE)target;
                                }
                                else static if(is(SCOPE == struct)) {
                                    bool isPtr = (target.type == typeid(SCOPE*));
                                    SCOPE* tar = isPtr ? cast(SCOPE*)target : cast(SCOPE*)target.ptr;
                                }
                                else {
                                    static assert(0, "instance type must be a class, interface, or struct*");
                                }

                                *value = cast(void*)tar + offset;
                            }
                            break;
                    }
                };

                target._fields ~= new Field(
                    __traits(identifier, mem),
                    FT.stringof,
                    typeid(FT),
                    toProtection!(__traits(getProtection, mem)),
                    fullyQualifiedName!FT,
                    offset,
                    isStatic,
                    operator);
            }
            else {
                //pragma(msg, "UNSUPPORTED SYMBOL: " ~ member);
            }
        }
        else
        {
            // @NoReflection
        }
    }

    return target;
}

static _rbool = reflect!bool;
static _rbyte = reflect!byte;
static _rubyte = reflect!ubyte;
static _rshort = reflect!short;
static _rushort = reflect!ushort;
static _rint = reflect!int;
static _ruint = reflect!uint;
static _rfloat = reflect!float;
static _rdouble = reflect!double;
static _rreal = reflect!real;
static _rchar = reflect!char;
static _rwchar = reflect!wchar;
static _rdchar = reflect!dchar;
//static _rifloat = reflect!ifloat;
//static _ridouble = reflect!idouble;
//static _rireal = reflect!ireal;
//static _rcfloat = reflect!cfloat;
//static _rcdouble = reflect!cdouble;
//static _rcreal = reflect!creal;

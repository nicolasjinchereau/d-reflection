module test;

class Test1
{
    int field1 = 1;
    float field2 = 2.0f;
    string field3 = "something";
    private int field4 = 123;

    void func1() {

    }

    final float func2(int arg1, bool arg2) {
        return field2;
    }

    @property private int prop1() {
        return field1;
    }

    @property private void prop1(int i) {
        field1 = i;
    }
}

class Test2 : Test1
{
    char character = 'c';
    
    void func4() {
        
    }

    override void func1() {

    }
}

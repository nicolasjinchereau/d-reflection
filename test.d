module test;

class Test1
{
    int field1 = 1;
    float field2 = 2.0f;
    string field3 = "something";
    private int field4 = 123;

    void func1() {

    }

    final int func2(int arg1, bool arg2) {
        return field1;
    }

    private void func3() {
        
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

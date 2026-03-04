#include "utils.h"

// Minimal C++ source: no system/platform headers — works without
// compile_commands.json and without MSVC developer environment.

int main()
{
    int a = MyApp::add(10, 20);
    int b = MyApp::subtract(100, a);
    int c = MyApp::multiply(a, b);
    return c == 0 ? 0 : 1;
}

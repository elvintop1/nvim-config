#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    system("g++ -std=c++17 -O2 -o gen gen.cpp");
    system("g++ -std=c++17 -O2 -o brute brute.cpp");
    system("g++ -std=c++17 -O2 -o main main.cpp");

    for (int test = 1; ; ++test) {
        system("gen > input.txt");
        system("brute < input.txt > brute.txt");
        system("main < input.txt > main.txt");

#ifdef _WIN32
        int diff = system("fc brute.txt main.txt > nul");
#else
        int diff = system("diff -u brute.txt main.txt > /dev/null");
#endif
        if (diff != 0) {
            cout << "Mismatch on test " << test << '\n';
            break;
        }
        cout << "Passed test " << test << '\n';
    }

    return 0;
}

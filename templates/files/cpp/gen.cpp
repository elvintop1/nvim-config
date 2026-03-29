#include <bits/stdc++.h>
using namespace std;

using ll = long long;

mt19937 rng((uint32_t)chrono::steady_clock::now().time_since_epoch().count());

int randint(int l, int r) {
    return uniform_int_distribution<int>(l, r)(rng);
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    return 0;
}

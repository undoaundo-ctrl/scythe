#include <iostream>
#include <string>
using namespace std;

int main() {
    string text = "Hello EVERYONE, i need to encrypt all because some privacy reason";
    int k = 73;

    for (char &c : text) {
        c ^= k;
    }

    cout << text << endl;
}
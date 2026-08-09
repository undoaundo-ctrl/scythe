// cube.cpp
// A classic rotating 3D ASCII cube rendered in the terminal.
// Compile: g++ -O2 -o cube cube.cpp -lm
// Run:     ./cube

#include <cmath>
#include <cstdio>
#include <cstring>
#include <unistd.h>

const int width = 160;
const int height = 44;
const float distanceFromCam = 100.0f;
const float K1 = 40.0f;
const float incrementSpeed = 0.6f;
const float cubeWidth = 20.0f;

float zBuffer[width * height];
char buffer[width * height];

float A = 0, B = 0, C = 0;

float calculateX(int i, int j, int k) {
    return j * sin(A) * sin(B) * cos(C) - k * cos(A) * sin(B) * cos(C) +
           j * cos(A) * sin(C) + k * sin(A) * sin(C) + i * cos(B) * cos(C);
}

float calculateY(int i, int j, int k) {
    return j * cos(A) * cos(C) + k * sin(A) * cos(C) -
           j * sin(A) * sin(B) * sin(C) + k * cos(A) * sin(B) * sin(C) -
           i * cos(B) * sin(C);
}

float calculateZ(int i, int j, int k) {
    return k * cos(A) * cos(B) - j * sin(A) * cos(B) + i * sin(B);
}

void calculateForSurface(float cubeX, float cubeY, float cubeZ, char ch) {
    float x = calculateX(cubeX, cubeY, cubeZ);
    float y = calculateY(cubeX, cubeY, cubeZ);
    float z = calculateZ(cubeX, cubeY, cubeZ) + distanceFromCam;

    float ooz = 1.0f / z;
    int xp = (int)(width / 2 + K1 * ooz * x * 2);
    int yp = (int)(height / 2 + K1 * ooz * y);

    int idx = xp + yp * width;
    if (idx >= 0 && idx < width * height) {
        if (ooz > zBuffer[idx]) {
            zBuffer[idx] = ooz;
            buffer[idx] = ch;
        }
    }
}

int main() {
    printf("\x1b[2J");
    while (true) {
        memset(buffer, ' ', width * height);
        memset(zBuffer, 0, sizeof(zBuffer));

        for (float cubeX = -cubeWidth; cubeX < cubeWidth; cubeX += 0.6f) {
            for (float cubeY = -cubeWidth; cubeY < cubeWidth; cubeY += 0.6f) {
                calculateForSurface(cubeX, cubeY, -cubeWidth, '@');
                calculateForSurface(cubeWidth, cubeY, cubeX, '$');
                calculateForSurface(-cubeWidth, cubeY, -cubeX, '~');
                calculateForSurface(-cubeX, cubeY, cubeWidth, '#');
                calculateForSurface(cubeX, -cubeWidth, -cubeY, ';');
                calculateForSurface(cubeX, cubeWidth, cubeY, '+');
            }
        }

        printf("\x1b[H");
        for (int k = 0; k < width * height; k++) {
            putchar(k % width ? buffer[k] : '\n');
        }

        A += 0.05f;
        B += incrementSpeed * 0.03f;
        C += 0.01f;
        usleep(8000 * 2);
    }
    return 0;
}

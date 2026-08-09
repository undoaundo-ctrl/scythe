// triangle.cpp
// A rotating 3D ASCII triangle (tetrahedron-style single face) rendered in the terminal.
// Compile: g++ -O2 -o triangle triangle.cpp -lm
// Run:     ./triangle

#include <cmath>
#include <cstdio>
#include <cstring>
#include <unistd.h>

const int width = 160;
const int height = 44;
const float distanceFromCam = 100.0f;
const float K1 = 40.0f;
const float triSize = 20.0f;

float zBuffer[width * height];
char buffer[width * height];

float A = 0, B = 0, C = 0;

float rotateX(float x, float y, float z) {
    return x * cos(B) * cos(C) + y * (sin(A) * sin(B) * cos(C) - cos(A) * sin(C)) +
           z * (cos(A) * sin(B) * cos(C) + sin(A) * sin(C));
}

float rotateY(float x, float y, float z) {
    return x * cos(B) * sin(C) + y * (sin(A) * sin(B) * sin(C) + cos(A) * cos(C)) +
           z * (cos(A) * sin(B) * sin(C) - sin(A) * cos(C));
}

float rotateZ(float x, float y, float z) {
    return -x * sin(B) + y * sin(A) * cos(B) + z * cos(A) * cos(B);
}

void plotPoint(float x0, float y0, float z0, char ch) {
    float x = rotateX(x0, y0, z0);
    float y = rotateY(x0, y0, z0);
    float z = rotateZ(x0, y0, z0) + distanceFromCam;

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

// Fill a triangle face by sampling barycentric coordinates across its surface.
void drawFace(float ax, float ay, float az, float bx, float by, float bz,
              float cx, float cy, float cz, char ch) {
    for (float u = 0; u <= 1.0f; u += 0.01f) {
        for (float v = 0; v <= 1.0f - u; v += 0.01f) {
            float w = 1.0f - u - v;
            float px = u * ax + v * bx + w * cx;
            float py = u * ay + v * by + w * cy;
            float pz = u * az + v * bz + w * cz;
            plotPoint(px, py, pz, ch);
        }
    }
}

int main() {
    printf("\x1b[2J");

    // Vertices of a tetrahedron (4 triangular faces).
    float s = triSize;
    float v0[3] = { 0,  s,  0 };
    float v1[3] = { -s, -s,  s };
    float v2[3] = { s, -s,  s };
    float v3[3] = { 0, -s, -s };

    while (true) {
        memset(buffer, ' ', width * height);
        memset(zBuffer, 0, sizeof(zBuffer));

        drawFace(v0[0], v0[1], v0[2], v1[0], v1[1], v1[2], v2[0], v2[1], v2[2], '@');
        drawFace(v0[0], v0[1], v0[2], v2[0], v2[1], v2[2], v3[0], v3[1], v3[2], '#');
        drawFace(v0[0], v0[1], v0[2], v3[0], v3[1], v3[2], v1[0], v1[1], v1[2], '$');
        drawFace(v1[0], v1[1], v1[2], v2[0], v2[1], v2[2], v3[0], v3[1], v3[2], '~');

        printf("\x1b[H");
        for (int k = 0; k < width * height; k++) {
            putchar(k % width ? buffer[k] : '\n');
        }

        A += 0.04f;
        B += 0.025f;
        C += 0.015f;
        usleep(16000);
    }
    return 0;
}

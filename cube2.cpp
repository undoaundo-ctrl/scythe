#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <string>

// Terminal dimensions
const int WIDTH = 80;
const int HEIGHT = 40;

// Screen buffers
std::vector<char> buffer(WIDTH * HEIGHT);
std::vector<float> zBuffer(WIDTH * HEIGHT);

// Math helper variables
const float BACKGROUND_CHAR = ' ';
const float DISTANCE_FROM_CAM = 100.0f;
const float K1 = 40.0f; // Scale factor for projection
const float INCREMENT_SPEED = 0.6f;

// Rotation angles
float A = 0.0f, B = 0.0f, C = 0.0f;

// Computes 3D coordinates after applying rotation matrices
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

// Renders a point belonging to a cube face into the 2D buffer
void calculateForSurface(float cubeX, float cubeY, float cubeZ, char ch) {
    // Apply rotations
    float x = calculateX(cubeX, cubeY, cubeZ);
    float y = calculateY(cubeX, cubeY, cubeZ);
    float z = calculateZ(cubeX, cubeY, cubeZ) + DISTANCE_FROM_CAM;

    // Perspective projection division
    float ooz = 1.0f / z;

    // Map 3D space to 2D terminal coordinates
    // Terminal characters are taller than they are wide, so multiply Y by 0.5 to fix aspect ratio
    int xp = static_cast<int>(WIDTH / 2 + K1 * 2 * x * ooz);
    int yp = static_cast<int>(HEIGHT / 2 + K1 * y * ooz * 0.5f);

    int idx = xp + yp * WIDTH;
    if (idx >= 0 && idx < WIDTH * HEIGHT) {
        if (xp >= 0 && xp < WIDTH && yp >= 0 && yp < HEIGHT) {
            // Z-buffer check to ensure closer surfaces cover distant surfaces
            if (ooz > zBuffer[idx]) {
                zBuffer[idx] = ooz;
                buffer[idx] = ch;
            }
        }
    }
}

int main() {
    // Hide terminal cursor for a cleaner look
    std::cout << "\x1b[?25l"; 

    // Clear the terminal screen initially
    std::cout << "\x1b[2J";

    // Set up the half-width dimension of the cube
    float cubeWidth = 20.0f;

    while (true) {
        // Clear frame buffers
        std::fill(buffer.begin(), buffer.end(), BACKGROUND_CHAR);
        std::fill(zBuffer.begin(), zBuffer.end(), 0.0f);

        // Render all 6 faces of the cube
        for (float cubeX = -cubeWidth; cubeX < cubeWidth; cubeX += INCREMENT_SPEED) {
            for (float cubeY = -cubeWidth; cubeY < cubeWidth; cubeY += INCREMENT_SPEED) {
                calculateForSurface(cubeX, cubeY, -cubeWidth, '.'); // Front
                calculateForSurface(cubeWidth, cubeY, cubeX, '$');  // Right
                calculateForSurface(-cubeWidth, cubeY, -cubeX, '~'); // Left
                calculateForSurface(-cubeX, cubeY, cubeWidth, '#');  // Back
                calculateForSurface(cubeX, -cubeWidth, -cubeY, ';'); // Top
                calculateForSurface(cubeX, cubeWidth, cubeY, '+');   // Bottom
            }
        }

        // Move cursor back to terminal origin (0,0) without clearing screen to minimize flicker
        std::cout << "\x1b[H";

        // Construct full string to print all at once for high-performance rendering
        std::string frameOutput = "";
        for (int i = 0; i < WIDTH * HEIGHT; i++) {
            frameOutput += buffer[i];
            if ((i + 1) % WIDTH == 0) {
                frameOutput += '\n';
            }
        }
        std::cout << frameOutput;

        // Increment rotation angles for the next frame
        A += 0.05f;
        B += 0.05f;
        C += 0.01f;

        // Frame rate limiter (~30 FPS)
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }

    return 0;
}

#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <thread>
#include <string>

// Terminal viewport dimensions
const int WIDTH = 80;
const int HEIGHT = 40;

int main() {
    // Hide terminal cursor for a cleaner look
    std::cout << "\x1b[?25l"; 
    // Clear the terminal screen initially
    std::cout << "\x1b[2J";

    // Textures representing light density levels (from bright to dark)
    const std::string palette = "@#$%=+*:-..      ";
    const int paletteSize = palette.length();

    float time = 0.0f;

    while (true) {
        std::string frameOutput = "";
        
        // Move terminal cursor back to origin (0,0) to prevent flickering
        std::cout << "\x1b[H";

        for (int y = 0; y < HEIGHT; y++) {
            // Normalize Y coordinate to range [-1.0, 1.0]
            float ny = (2.0f * y / HEIGHT) - 1.0f;
            
            // Adjust for terminal character aspect ratio (characters are taller than they are wide)
            ny *= 0.5f; 

            for (int x = 0; x < WIDTH; x++) {
                // Normalize X coordinate to range [-1.0, 1.0]
                float nx = (2.0f * x / WIDTH) - 1.0f;

                // Calculate distance (r) from the center of the black hole
                float r = std::sqrt(nx * nx + ny * ny);
                
                // Calculate angular position (theta) for accretion disk rotation
                float theta = std::atan2(ny, nx);

                // Define the radius of the Event Horizon (the point of no return)
                float eventHorizon = 0.25f;

                if (r <= eventHorizon) {
                    // Inside the Event Horizon: light cannot escape
                    frameOutput += ' ';
                } else {
                    // Gravitational Lensing simulation: Light bends drastically near the horizon.
                    // We invert the radius math to warp space inward.
                    float warpedR = 1.0f / (r - eventHorizon + 0.01f);
                    
                    // Create an accretion disk wave pattern spinning around the singularity
                    // Mixing warped distance, angle, and time creates a spiral fluid dynamic effect
                    float dynamicWave = std::sin(warpedR * 1.5f - theta * 3.0f + time * 4.0f);
                    float secondaryWave = std::cos(theta * 1.0f + time * 1.5f);
                    
                    // Calculate final light brightness value
                    float brightness = (dynamicWave * 0.5f + 0.5f) * (secondaryWave * 0.3f + 0.7f);
                    
                    // Falloff intensity: Light naturally dims as it moves far away from the core
                    float falloff = std::exp(-2.0f * (r - eventHorizon));
                    brightness *= falloff;

                    // Map brightness to our ASCII texture palette string
                    int paletteIdx = static_cast<int>((1.0f - brightness) * (paletteSize - 1));
                    
                    // Clamping index limits safely
                    if (paletteIdx < 0) paletteIdx = 0;
                    if (paletteIdx >= paletteSize) paletteIdx = paletteSize - 1;

                    frameOutput += palette[paletteIdx];
                }
            }
            frameOutput += '\n';
        }

        // Print the rendered string buffer all at once
        std::cout << frameOutput;

        // Advance time for animations
        time += 0.05f;

        // Limit frame rate (~30 frames per second)
        std::this_thread::sleep_for(std::chrono::milliseconds(33));
    }

    return 0;
}

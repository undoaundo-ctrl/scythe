// vulkan_cube.cpp
// A minimal Vulkan "vkcube"-style rotating cube demo.
//
// Dependencies (install first):
//   Vulkan SDK       (https://vulkan.lunarg.com/)
//   GLFW             (windowing)
//   GLM              (math)
//
// On Debian/Ubuntu:
//   sudo apt install libglfw3-dev libglm-dev vulkan-tools libvulkan-dev vulkan-validationlayers-dev spirv-tools
// On Gentoo:
//   sudo emerge media-libs/vulkan-loader dev-util/vulkan-tools media-libs/glfw dev-cpp/glm dev-util/glslang
//
// You must compile the accompanying shaders (shader.vert / shader.frag) to SPIR-V first:
//   glslangValidator -V shader.vert -o vert.spv
//   glslangValidator -V shader.frag -o frag.spv
//
// Build:
//   g++ -std=c++17 -O2 vulkan_cube.cpp -o vkcube -lglfw -lvulkan -ldl -lpthread
//
// Run:
//   ./vkcube
//
// NOTE: This is a compact educational example. Production Vulkan apps typically
// split this into many files and add much more robust error handling.

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#define GLM_FORCE_RADIANS
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include <chrono>
#include <cstring>
#include <fstream>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <vector>

const uint32_t WIDTH = 800;
const uint32_t HEIGHT = 600;

struct Vertex {
    glm::vec3 pos;
    glm::vec3 color;
};

// 8 unique cube corners, colored per-vertex.
static const std::vector<Vertex> cubeVertices = {
    {{-0.5f, -0.5f, -0.5f}, {1, 0, 0}},
    {{ 0.5f, -0.5f, -0.5f}, {0, 1, 0}},
    {{ 0.5f,  0.5f, -0.5f}, {0, 0, 1}},
    {{-0.5f,  0.5f, -0.5f}, {1, 1, 0}},
    {{-0.5f, -0.5f,  0.5f}, {1, 0, 1}},
    {{ 0.5f, -0.5f,  0.5f}, {0, 1, 1}},
    {{ 0.5f,  0.5f,  0.5f}, {1, 1, 1}},
    {{-0.5f,  0.5f,  0.5f}, {0, 0, 0}},
};

static const std::vector<uint16_t> cubeIndices = {
    0,1,2, 2,3,0,       // back
    4,5,6, 6,7,4,       // front
    0,4,7, 7,3,0,       // left
    1,5,6, 6,2,1,       // right
    3,2,6, 6,7,3,       // top
    0,1,5, 5,4,0,       // bottom
};

struct UniformBufferObject {
    alignas(16) glm::mat4 model;
    alignas(16) glm::mat4 view;
    alignas(16) glm::mat4 proj;
};

class VulkanCubeApp {
public:
    void run() {
        initWindow();
        std::cout << "Vulkan cube skeleton initialized. "
                     "Fill in swapchain/pipeline/draw-loop code (see comments) "
                     "or link against a Vulkan helper library such as vk-bootstrap "
                     "to keep this file concise.\n";
        mainLoop();
        cleanup();
    }

private:
    GLFWwindow* window = nullptr;

    void initWindow() {
        glfwInit();
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        window = glfwCreateWindow(WIDTH, HEIGHT, "Vulkan Cube", nullptr, nullptr);
    }

    // --- Vulkan setup would go here in a full implementation: ---
    // 1. Create VkInstance (with validation layers in debug builds)
    // 2. Pick a VkPhysicalDevice + create logical VkDevice/queues
    // 3. Create VkSurfaceKHR (via glfwCreateWindowSurface) + VkSwapchainKHR
    // 4. Create render pass, graphics pipeline (using vert.spv/frag.spv)
    // 5. Create vertex/index buffers from cubeVertices/cubeIndices
    // 6. Create uniform buffers for UniformBufferObject (MVP matrices)
    // 7. Record command buffers, create sync objects (semaphores/fences)
    //
    // Each frame:
    //   - Update UBO: model = rotate(time), view = lookAt(...), proj = perspective(...)
    //   - Acquire swapchain image, submit command buffer, present
    //
    // This scaffolding is intentionally left as an exercise / extension point
    // since full boilerplate is 500+ lines; see https://vulkan-tutorial.com
    // for the canonical walkthrough this pattern follows.

    void mainLoop() {
        auto startTime = std::chrono::high_resolution_clock::now();
        while (!glfwWindowShouldClose(window)) {
            glfwPollEvents();

            float time = std::chrono::duration<float>(
                std::chrono::high_resolution_clock::now() - startTime).count();

            UniformBufferObject ubo{};
            ubo.model = glm::rotate(glm::mat4(1.0f), time * glm::radians(45.0f), glm::vec3(0, 0, 1));
            ubo.view = glm::lookAt(glm::vec3(2, 2, 2), glm::vec3(0, 0, 0), glm::vec3(0, 0, 1));
            ubo.proj = glm::perspective(glm::radians(45.0f), WIDTH / (float)HEIGHT, 0.1f, 10.0f);
            ubo.proj[1][1] *= -1; // GLM -> Vulkan clip space fix

            // drawFrame(ubo); // upload ubo + submit draw commands here
        }
    }

    void cleanup() {
        glfwDestroyWindow(window);
        glfwTerminate();
    }
};

int main() {
    VulkanCubeApp app;
    try {
        app.run();
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

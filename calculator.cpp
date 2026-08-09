#include <iostream>
#include <limits>

int main() {
    double num1 = 0.0;
    double num2 = 0.0;
    char op = ' ';
    double result = 0.0;
    int error_flag = 0; // 0 = Success, 1 = Division by zero, 2 = Invalid Operator

    std::cout << "=== Hybrid C++ / Assembly Calculator ===\n";
    std::cout << "Enter expression (e.g., 12.5 + 4.2): ";
    
    if (!(std::cin >> num1 >> op >> num2)) {
        std::cout << "Error: Invalid numeric input formatting.\n";
        return 1;
    }

    // Inline x86_64 Assembly Block using AT&T Syntax (Standard for GCC/Clang Linux)
    __asm__ volatile (
        "movq %1, %%xmm0\n\t"        // Load num1 into SSE register xmm0
        "movq %2, %%xmm1\n\t"        // Load num2 into SSE register xmm1
        
        // --- Parse Operator Character ---
        "cmpb $43, %b3\n\t"          // Compare op with '+' (ASCII 43)
        "je .add_op\n\t"
        "cmpb $45, %b3\n\t"          // Compare op with '-' (ASCII 45)
        "je .sub_op\n\t"
        "cmpb $42, %b3\n\t"          // Compare op with '*' (ASCII 42)
        "je .mul_op\n\t"
        "cmpb $47, %b3\n\t"          // Compare op with '/' (ASCII 47)
        "je .div_op\n\t"
        
        // Invalid Operator Route
        "movl $2, %0\n\t"            // Set error_flag = 2
        "jmp .done\n\t"

    ".add_op:\n\t"
        "addsd %%xmm1, %%xmm0\n\t"   // xmm0 = num1 + num2
        "jmp .save_res\n\t"

    ".sub_op:\n\t"
        "subsd %%xmm1, %%xmm0\n\t"   // xmm0 = num1 - num2
        "jmp .save_res\n\t"

    ".mul_op:\n\t"
        "mulsd %%xmm1, %%xmm0\n\t"   // xmm0 = num1 * num2
        "jmp .save_res\n\t"

    ".div_op:\n\t"
        // --- Division by Zero Check ---
        "xorpd %%xmm2, %%xmm2\n\t"   // Clear xmm2 to 0.0
        "ucomisd %%xmm2, %%xmm1\n\t" // Compare num2 with 0.0
        "jp .exec_div\n\t"           // Jump if unordered (NaN handling safety)
        "je .div_zero_error\n\t"     // Jump if equal to zero

    ".exec_div:\n\t"
        "divsd %%xmm1, %%xmm0\n\t"   // xmm0 = num1 / num2
        "jmp .save_res\n\t"

    ".div_zero_error:\n\t"
        "movl $1, %0\n\t"            // Set error_flag = 1
        "jmp .done\n\t"

    ".save_res:\n\t"
        "movq %%xmm0, %4\n\t"        // Store xmm0 back out to result variable

    ".done:\n\t"
        : "=r" (error_flag)                              // %0: Output variable
        : "m" (num1), "m" (num2), "r" (op), "m" (result) // %1, %2, %3, %4: Inputs
        : "xmm0", "xmm1", "xmm2", "cc"                   // Clobbered registers/flags
    );

    // --- Process Output Framework ---
    if (error_flag == 1) {
        std::cout << "Runtime Error: Division by zero is undefined.\n";
    } else if (error_flag == 2) {
        std::cout << "Syntax Error: Unknown operator '" << op << "'. Use +, -, *, or /.\n";
    } else {
        std::cout << "Result: " << result << "\n";
    }

    return 0;
}

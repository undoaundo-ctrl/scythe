#include <iostream>
#include <chrono>
#include <iomanip>
#include <thread>

// Platform-specific clear screen to prevent flickering
void clearScreen() {
#if defined(_WIN32)
    std::system("cls");
#else
    // ANSI escape code to clear screen and home cursor
    std::cout << "\033[2J\033[H";
#endif
}

int main() {
    std::cout << "=== Real-Time Digital Clock ===\n";
    std::cout << "Press Ctrl+C in your terminal to exit.\n\n";
    
    // Hide terminal cursor for cleaner presentation (ANSI supported)
    std::cout << "\033[?25l" << std::flush;

    while (true) {
        // 1. Get current system clock time point
        auto now = std::chrono::system_clock::now();
        
        // 2. Convert to historical time_t layout structure
        std::time_t currentTime = std::chrono::system_clock::to_time_t(now);
        
        // 3. Thread-safe parsing conversion to local time zone calendar items
        std::tm* localTime = std::localtime(&currentTime);

        // 4. Wipe canvas frame layout
        clearScreen();

        // 5. Output formatted time string to terminal
        std::cout << "=========================\n";
        std::cout << "  LOCAL TIME: " 
                  << std::setfill('0') 
                  << std::setw(2) << localTime->tm_hour << ":"
                  << std::setw(2) << localTime->tm_min << ":"
                  << std::setw(2) << localTime->tm_sec << "\n";
        std::cout << "  DATE:       "
                  << (localTime->tm_year + 1900) << "-"
                  << std::setw(2) << (localTime->tm_mon + 1) << "-"
                  << std::setw(2) << localTime->tm_mday << "\n";
        std::cout << "=========================\n";
        std::flush(std::cout);

        // 6. Throttle clock iterations to sleep for 1 absolute second
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    // Restore text terminal cursor layout mapping configuration on termination
    std::cout << "\033[?25h" << std::flush;
    return 0;
}

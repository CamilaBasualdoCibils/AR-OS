#include "EmulatorApplication.hpp"

#include <AROS/DeviceEmulator/RfbTransport.hpp>

#include <exception>
#include <iostream>
#include <memory>

int main()
{
    try {
        AROS::DeviceEmulator::EmulatorApplication application(
            std::make_unique<AROS::DeviceEmulator::RfbTransport>());
        return application.Run();
    } catch (const std::exception& error) {
        std::cerr << "AR-OS Device Emulator: " << error.what() << '\n';
        return 1;
    }
}

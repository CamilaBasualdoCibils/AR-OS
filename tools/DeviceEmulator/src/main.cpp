#include "EmulatorApplication.hpp"

#include <VISROS/DeviceEmulator/SandboxTransport.hpp>

#include <exception>
#include <iostream>
#include <memory>

int main()
{
    try {
        VISROS::DeviceEmulator::EmulatorApplication application(
            std::make_unique<VISROS::DeviceEmulator::SandboxTransport>());
        return application.Run();
    } catch (const std::exception& error) {
        std::cerr << "VISR OS Device Emulator: " << error.what() << '\n';
        return 1;
    }
}

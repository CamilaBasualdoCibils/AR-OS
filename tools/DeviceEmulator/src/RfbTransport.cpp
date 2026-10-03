#include <AROS/DeviceEmulator/RfbTransport.hpp>
#include <AROS/DeviceEmulator/EmulatedXRDevice.hpp>
namespace AROS::DeviceEmulator {
RfbTransport::RfbTransport(std::string host,std::uint16_t port):name_("QEMU RFB "+host+":"+std::to_string(port)),client_(std::move(host),port,"Device Emulator"){}
RfbTransport::~RfbTransport()=default;
void RfbTransport::Poll(EmulatedXRDevice& d){VirtualDisplay::Frame f;if(client_.Poll(f))d.SubmitBootImage(f.width,f.height,f.rgba);}
bool RfbTransport::Connected()const noexcept{return client_.Connected();}
std::string_view RfbTransport::Name()const noexcept{return name_;}
}

#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "kiosk_shell.h"

namespace {

constexpr char kChannel[] = "psclub/kiosk";

class KioskChannel {
 public:
  static void Register(flutter::FlutterEngine* engine) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), kChannel,
            &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          const std::string& method = call.method_name();
          if (method == "setEnabled") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            bool enabled = false;
            if (args) {
              auto it = args->find(flutter::EncodableValue("enabled"));
              if (it != args->end()) {
                if (const auto* v = std::get_if<bool>(&it->second)) {
                  enabled = *v;
                }
              }
            }
            EnableKioskShell(enabled);
            result->Success();
            return;
          }
          result->NotImplemented();
        });

    // Keep channel alive for app lifetime.
    static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> s_channel;
    s_channel = std::move(channel);
  }
};

}  // namespace

void RegisterKioskChannel(flutter::FlutterEngine* engine) {
  KioskChannel::Register(engine);
}

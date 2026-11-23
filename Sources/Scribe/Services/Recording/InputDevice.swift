import CoreAudio
import Foundation

enum InputDevice {
  static var defaultIsBluetooth: Bool {
    guard let device = defaultInputDevice, let transport = transportType(of: device) else {
      return false
    }
    return transport == kAudioDeviceTransportTypeBluetooth
      || transport == kAudioDeviceTransportTypeBluetoothLE
  }

  private static var defaultInputDevice: AudioDeviceID? {
    var device = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
    guard status == noErr, device != kAudioObjectUnknown else { return nil }
    return device
  }

  private static func transportType(of device: AudioDeviceID) -> UInt32? {
    var transport: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyTransportType,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport) == noErr else {
      return nil
    }
    return transport
  }
}

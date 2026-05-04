enum SensorChannelType {
  emg,
  imu,
}

enum SensorSide {
  left,
  right,
  center,
}

class SensorPlacement {
  const SensorPlacement({
    required this.channelType,
    required this.channelNumber,
    required this.side,
    required this.fixedRole,
    required this.displayName,
    required this.dataKey,
    required this.attachmentLocation,
    required this.analysisPurpose,
  });

  final SensorChannelType channelType;
  final int channelNumber;
  final SensorSide side;
  final String fixedRole;
  final String displayName;
  final String dataKey;
  final String attachmentLocation;
  final String analysisPurpose;

  String get channelLabel {
    final prefix = channelType == SensorChannelType.emg ? 'EMG' : 'IMU';
    return '$prefix$channelNumber';
  }
}

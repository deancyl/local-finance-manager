/// PowerSync credentials placeholder.
/// 
/// Defined locally to avoid dependency on powersync package while sync is disabled.
/// When PowerSync is re-integrated, this should use the real PowerSyncCredentials.
class PowerSyncCredentials {
  final String endpoint;
  final String token;
  final String? userId;
  final DateTime? expiresAt;

  PowerSyncCredentials({
    required this.endpoint,
    required this.token,
    this.userId,
    this.expiresAt,
  });
}

/// Credentials for PowerSync synchronization.
/// 
/// Contains endpoint information, authentication token, and expiration details
/// for connecting to the PowerSync sync server.
class SyncCredentials {
  /// The PowerSync sync endpoint URL.
  final String endpoint;
  
  /// Authentication token for the sync server.
  final String token;
  
  /// Optional user ID associated with these credentials.
  final String? userId;
  
  /// Optional expiration time for the token.
  final DateTime? expiresAt;

  SyncCredentials({
    required this.endpoint,
    required this.token,
    this.userId,
    this.expiresAt,
  });

  /// Creates SyncCredentials from PowerSync's native credentials format.
  factory SyncCredentials.fromPowerSync(PowerSyncCredentials creds) {
    return SyncCredentials(
      endpoint: creds.endpoint,
      token: creds.token,
      userId: creds.userId,
      expiresAt: creds.expiresAt,
    );
  }

  /// Converts to PowerSync's native credentials format.
  PowerSyncCredentials toPowerSync() {
    return PowerSyncCredentials(
      endpoint: endpoint,
      token: token,
      userId: userId,
      expiresAt: expiresAt,
    );
  }

  /// Returns true if the credentials have expired.
  /// 
  /// Returns false if [expiresAt] is null (no expiration set).
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Returns true if credentials will expire within the given duration.
  bool willExpireWithin(Duration duration) {
    if (expiresAt == null) return false;
    return DateTime.now().add(duration).isAfter(expiresAt!);
  }

  /// Creates a copy with optionally updated fields.
  SyncCredentials copyWith({
    String? endpoint,
    String? token,
    String? userId,
    DateTime? expiresAt,
  }) {
    return SyncCredentials(
      endpoint: endpoint ?? this.endpoint,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Serializes credentials to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'token': token,
      'userId': userId,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  /// Creates credentials from a JSON map.
  factory SyncCredentials.fromJson(Map<String, dynamic> json) {
    return SyncCredentials(
      endpoint: json['endpoint'] as String,
      token: json['token'] as String,
      userId: json['userId'] as String?,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'SyncCredentials(endpoint: $endpoint, userId: $userId, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncCredentials &&
        other.endpoint == endpoint &&
        other.token == token &&
        other.userId == userId &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(endpoint, token, userId, expiresAt);
  }
}

/// Represents a device registered for synchronization.
/// 
/// Contains device identification, name, public key for E2E encryption,
/// and timestamps for creation and last sync.
class SyncDevice {
  /// Unique identifier for this device.
  final String id;
  
  /// Human-readable name for the device.
  final String name;
  
  /// Optional public key for end-to-end encryption.
  final String? publicKey;
  
  /// When this device was registered.
  final DateTime createdAt;
  
  /// When this device last performed a sync.
  final DateTime? lastSyncAt;

  SyncDevice({
    required this.id,
    required this.name,
    this.publicKey,
    required this.createdAt,
    this.lastSyncAt,
  });

  /// Creates a SyncDevice from a JSON map.
  factory SyncDevice.fromJson(Map<String, dynamic> json) {
    return SyncDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      publicKey: json['publicKey'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
    );
  }

  /// Serializes the device to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publicKey': publicKey,
      'createdAt': createdAt.toIso8601String(),
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }

  /// Creates a copy with optionally updated fields.
  SyncDevice copyWith({
    String? id,
    String? name,
    String? publicKey,
    DateTime? createdAt,
    DateTime? lastSyncAt,
  }) {
    return SyncDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  /// Returns true if this device has a public key configured.
  bool get hasPublicKey => publicKey != null && publicKey!.isNotEmpty;

  /// Returns true if this device has synced before.
  bool get hasSynced => lastSyncAt != null;

  @override
  String toString() {
    return 'SyncDevice(id: $id, name: $name, lastSyncAt: $lastSyncAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncDevice &&
        other.id == id &&
        other.name == name &&
        other.publicKey == publicKey &&
        other.createdAt == createdAt &&
        other.lastSyncAt == lastSyncAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, publicKey, createdAt, lastSyncAt);
  }
}

/// Status of a sync operation.
enum SyncStatus {
  /// SyncClient not initialized yet.
  notInitialized,
  
  /// Disconnected from sync server.
  disconnected,
  
  /// Currently connecting to sync server.
  connecting,
  
  /// Connected and syncing.
  connected,
  
  /// Error state.
  error,
}

/// Extension to provide human-readable status.
extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.notInitialized:
        return 'Not Initialized';
      case SyncStatus.disconnected:
        return 'Disconnected';
      case SyncStatus.connecting:
        return 'Connecting';
      case SyncStatus.connected:
        return 'Connected';
      case SyncStatus.error:
        return 'Error';
    }
  }

  bool get isReady => this == SyncStatus.connected;
  bool get hasError => this == SyncStatus.error;
}

/// Result of a sync operation.
class SyncResult {
  /// Whether the sync completed successfully.
  final bool success;
  
  /// Error message if sync failed.
  final String? error;
  
  /// Number of uploads performed.
  final int uploads;
  
  /// Number of downloads performed.
  final int downloads;
  
  /// Timestamp when sync completed.
  final DateTime completedAt;

  SyncResult({
    required this.success,
    this.error,
    this.uploads = 0,
    this.downloads = 0,
    required this.completedAt,
  });

  /// Creates a successful sync result.
  factory SyncResult.success({
    int uploads = 0,
    int downloads = 0,
  }) {
    return SyncResult(
      success: true,
      uploads: uploads,
      downloads: downloads,
      completedAt: DateTime.now(),
    );
  }

  /// Creates a failed sync result.
  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      error: error,
      completedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    if (success) {
      return 'SyncResult.success(uploads: $uploads, downloads: $downloads)';
    }
    return 'SyncResult.failure($error)';
  }
}

/// Sync progress information.
class SyncProgress {
  /// Current sync status.
  final SyncStatus status;
  
  /// Number of pending uploads.
  final int pendingUploads;
  
  /// Number of pending downloads.
  final int pendingDownloads;
  
  /// Last successful sync time.
  final DateTime? lastSyncTime;
  
  /// Error message if status is error.
  final String? errorMessage;

  const SyncProgress({
    required this.status,
    this.pendingUploads = 0,
    this.pendingDownloads = 0,
    this.lastSyncTime,
    this.errorMessage,
  });

  /// Creates a copy with optional overrides.
  SyncProgress copyWith({
    SyncStatus? status,
    int? pendingUploads,
    int? pendingDownloads,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncProgress(
      status: status ?? this.status,
      pendingUploads: pendingUploads ?? this.pendingUploads,
      pendingDownloads: pendingDownloads ?? this.pendingDownloads,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Progress percentage (0.0 to 1.0).
  double get progress {
    if (pendingUploads == 0 && pendingDownloads == 0) {
      return 1.0;
    }
    final total = pendingUploads + pendingDownloads;
    if (total == 0) return 1.0;
    return 0.5; // Unknown progress
  }
}

/// Sync conflict information.
class SyncConflict {
  /// Table where conflict occurred.
  final String table;
  
  /// ID of conflicting row.
  final String id;
  
  /// Local version of the data.
  final Map<String, dynamic>? localData;
  
  /// Remote version of the data.
  final Map<String, dynamic>? remoteData;
  
  /// Timestamp of conflict.
  final DateTime timestamp;

  const SyncConflict({
    required this.table,
    required this.id,
    this.localData,
    this.remoteData,
    required this.timestamp,
  });
}

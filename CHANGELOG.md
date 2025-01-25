# Changelog

## [1.1.1] - 25.01.2025

### Added
- `config.example`: Added `RESTORE_USER` configuration for restoring processes where user change may be necessary.

- `docker_restore.sh`:
    - Implemented user selection for restoring processes allowing changes to user directories dynamically.
    - Added logging of restored paths with user adjustments.
    - Integrated calling of the new `update_user_in_docker_config.sh` script for updating Docker configurations.

- `scripts/update_user_in_docker_config.sh`:
    - New script for updating user paths in `container_configs.json`. It replaces specific usernames within Docker volume bindings with a new username as specified.

### Updated
- `docker_backup.sh` & `docker_restore.sh`:
    - Updated script version to `1.1.1`.
    - Changed last modified date to `25.01.2025`.

- `docker_restore.sh`:
    - Altered Docker installation instructions to provide external guidance.
    - Enhanced the home extraction process to include transformations for user customization.
    - Revised permission correction to focus on specific `RESTORE_USER`.

### Removed
- `docker_restore.sh`:
    - Removed inline Docker installation process in favor of external instructions to streamline the script and avoid automated installations.

### Fixed
- Ensured line ending consistency to mitigate LF to CRLF related warnings across the scripts.


## [1.1.0] - January 2025

### New Features
- Implementation of a robust backup rotation system.
- Introduction of a backup status check.
- Optional encryption of backups.
- Ability to selectively restore containers and volumes.

### Improvements
- Utilization of filesystem timestamps instead of directory names for more accurate age determination.
- Enhanced error handling and logging across all scripts.
- Optimized disk space usage through automatic deletion of outdated backups.

### Detailed Changes

#### Backup Rotation (`cleanup_old_backups.sh`)
- Automatic cleanup of old backups based on configurable retention policies.
- Retention of daily, weekly, and monthly backups for a specified period.
- Use of `stat` for precise age determination of backup directories.

#### Backup Status Check (`check_backup_status.sh`)
- Verification of the age of the latest backup.
- Analysis of backup size and available disk space.
- Integrity check of backup files (Docker images and volumes).

#### Optional Encryption (`encrypt_backup.sh`)
- AES-256 encryption for sensitive backup data.
- Secure password generation and storage.
- Compatibility with the restore process.

#### Selective Restore
- Ability to restore individual containers or volumes.
- Improved flexibility in data recovery.

#### General Enhancements
- More extensive logging for improved traceability.
- Optimized error handling across all scripts.
- Improved compatibility with various backup naming conventions.

### Bug Fixes
- Correction of date calculation issues in all scripts.

## [1.0.1] - January 2025
- Fixed errors in the configuration.
- Updated the README.

## [1.0] - January 2025
- Initial version.
- Complete backup and restore system.
- Logging system implemented.
- Error handling implemented.


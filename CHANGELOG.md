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

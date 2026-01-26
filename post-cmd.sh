#!/bin/bash

set -euo pipefail

_check_dependencies() {
	local missing_deps=()

	for cmd in rsync realpath basename compgen mkdir; do
		if ! command -v "${cmd}" &>/dev/null; then
			missing_deps+=("${cmd}")
		fi
	done

	if [ ${#missing_deps[@]} -gt 0 ]; then
		echo "Error: Missing required commands: ${missing_deps[*]}" >&2
		echo "Please install the missing dependencies and try again." >&2
		exit 1
	fi
}

_load_env_files() {
	local env_file=".env"
	local env_files=("${env_file}")

	# Check for environment-specific .env files (same logic as bootstrap.php)
	if [[ -n "${APP_ENV:-}" ]]; then
		env_files+=("${env_file}.${APP_ENV}")
	fi

	# Load .env files in order (later files override earlier ones)
	for file in "${env_files[@]}"; do
		if [[ -f "${file}" ]]; then
			echo "Loading environment from: ${file}"
			# Export variables while preserving quotes and handling comments
			set -a
			# shellcheck disable=SC1090
			source <(grep -v '^[[:space:]]*#' "${file}" | grep -v '^[[:space:]]*$')
			set +a
		fi
	done
}

main() {
	_check_dependencies

	# Load .env files
	_load_env_files

	# Check if sync is enabled
	if [[ "${WP_BOOT_SYNC_ENABLED:-false}" != "true" ]]; then
		echo "WordPress sync is disabled (WP_BOOT_SYNC_ENABLED is not set to 'true')."
		echo "To enable sync, set WP_BOOT_SYNC_ENABLED=true in your .env file."
		exit 0
	fi

	if [[ "$#" -lt 1 ]]; then
		echo "Missing argument 'dest'." >&2
		echo "Use: $0 <dest>"
		exit 1
	fi

	local dest_dir
	dest_dir=$(realpath "$1")

	echo "Called $0 with these arguments:"
	echo "dest: ${dest_dir}"

	_manage_files "${dest_dir}"
}

#https://unix.stackexchange.com/a/77737
#https://stackoverflow.com/a/246128
#https://andy-carter.com/blog/automating-npm-and-composer-with-git-hooks
_manage_files() {
	declare dest_dir="$1"

	echo "Syncing files to: ${dest_dir}"

	# Create destination directory if it doesn't exist
	mkdir -p "${dest_dir}"

	# Sync WordPress core directories (with delete option)
	echo "Syncing WordPress core directories..."
	rsync -a --delete --stats \
		--filter=". ${PWD}/rsync-dirs.txt" \
		"${PWD}/vendor/wordpress/" "${dest_dir}/"

	# Sync WordPress root files only (no directories, no delete)
	echo "Syncing WordPress root files..."
	rsync -a --stats \
		--filter=". ${PWD}/rsync-files.txt" \
		"${PWD}/vendor/wordpress/" "${dest_dir}/"

	# Sync wp-content PHP files if they exist
	if [ -f "${PWD}/vendor/wordpress/wp-content/index.php" ] || compgen -G "${PWD}/vendor/wordpress/wp-content/*.php" >/dev/null; then
		echo "Syncing wp-content PHP files..."
		mkdir -p "${dest_dir}/wp-content"
		rsync -a --stats \
			--include='*.php' \
			--exclude='*' \
			"${PWD}/vendor/wordpress/wp-content/" "${dest_dir}/wp-content/"
	fi

	# Sync wp-content/plugins PHP files if they exist
	if compgen -G "${PWD}/vendor/wordpress/wp-content/plugins/*.php" >/dev/null; then
		echo "Syncing wp-content/plugins PHP files..."
		mkdir -p "${dest_dir}/wp-content/plugins"
		rsync -a --stats \
			--include='*.php' \
			--exclude='*' \
			"${PWD}/vendor/wordpress/wp-content/plugins/" "${dest_dir}/wp-content/plugins/"
		rm -f "${dest_dir}/wp-content/plugins/hello.php"
	fi

	# Sync wp-content/themes PHP files if they exist
	if compgen -G "${PWD}/vendor/wordpress/wp-content/themes/*.php" >/dev/null; then
		echo "Syncing wp-content/themes PHP files..."
		mkdir -p "${dest_dir}/wp-content/themes"
		rsync -a --stats \
			--include='*.php' \
			--exclude='*' \
			"${PWD}/vendor/wordpress/wp-content/themes/" "${dest_dir}/wp-content/themes/"
	fi

	# Sync default WordPress plugins
	if [ -d "${PWD}/vendor/wordpress/wp-content/plugins" ]; then
		echo "Syncing default WordPress plugins..."
		for plugin_dir in "${PWD}/vendor/wordpress/wp-content/plugins"/*; do
			if [ -d "${plugin_dir}" ]; then
				plugin_name=$(basename "${plugin_dir}")
				echo "  - Syncing plugin: ${plugin_name}"
				mkdir -p "${dest_dir}/wp-content/plugins/${plugin_name}"
				rsync -a --delete --stats \
					"${plugin_dir}/" "${dest_dir}/wp-content/plugins/${plugin_name}/"
			fi
		done
	fi

	# Sync default WordPress themes
	if [ -d "${PWD}/vendor/wordpress/wp-content/themes" ]; then
		echo "Syncing default WordPress themes..."
		for theme_dir in "${PWD}/vendor/wordpress/wp-content/themes"/*; do
			if [ -d "${theme_dir}" ]; then
				theme_name=$(basename "${theme_dir}")
				echo "  - Syncing theme: ${theme_name}"
				mkdir -p "${dest_dir}/wp-content/themes/${theme_name}"
				rsync -a --delete --stats \
					"${theme_dir}/" "${dest_dir}/wp-content/themes/${theme_name}/"
			fi
		done
	fi

	echo "WordPress sync completed successfully!"

	if [[ "${APP_ENV:-production}" != "production" ]]; then
		if [[ ! -f "${dest_dir}/.user-${APP_ENV}.ini" ]] && [[ -f "${dest_dir}/.user.ini.dist" ]]; then
			cp -a "${dest_dir}/.user.ini.dist" "${dest_dir}/.user-${APP_ENV}.ini"
		fi
	elif [[ ! -f "${dest_dir}/.user.ini" ]] && [[ -f "${dest_dir}/.user.ini.dist" ]]; then
		cp -a "${dest_dir}/.user.ini.dist" "${dest_dir}/.user.ini"
	fi

	if [[ ! -f "${dest_dir}/.htaccess" ]] && [[ -f "${dest_dir}/.htaccess.dist" ]]; then
		cp -a "${dest_dir}/.htaccess.dist" "${dest_dir}/.htaccess"
	fi

	# https://github.com/cweagans/composer-patches/issues/280
	# https://github.com/roots/docs/issues/424
	if [[ ! -f "${dest_dir}/wp-config.php" ]] && [[ -f "${dest_dir}/wp-config.php.dist" ]]; then
		cp -a "${dest_dir}/wp-config.php.dist" "${dest_dir}/wp-config.php"
	fi
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

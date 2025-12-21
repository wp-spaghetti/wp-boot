![PHP Version](https://img.shields.io/packagist/php-v/wp-spaghetti/wp-boot)
![Packagist Downloads](https://img.shields.io/packagist/dt/wp-spaghetti/wp-boot)
![Packagist Stars](https://img.shields.io/packagist/stars/wp-spaghetti/wp-boot)
![GitHub Actions Workflow Status](https://github.com/wp-spaghetti/wp-boot/actions/workflows/main.yml/badge.svg)
![Coverage Status](https://img.shields.io/codecov/c/github/wp-spaghetti/wp-boot)
![Known Vulnerabilities](https://snyk.io/test/github/wp-spaghetti/wp-boot/badge.svg)
![GitHub Issues](https://img.shields.io/github/issues/wp-spaghetti/wp-boot)

![GitHub Release](https://img.shields.io/github/v/release/wp-spaghetti/wp-boot)
![License](https://img.shields.io/github/license/wp-spaghetti/wp-boot)
<!--
Qlty @see https://github.com/badges/shields/issues/11192
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/wp-spaghetti/wp-boot/total)
![Code Climate](https://img.shields.io/codeclimate/maintainability/wp-spaghetti/wp-boot)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)
-->

# WP Boot

**WP Boot** is a lightweight Composer-based WordPress management system designed for scenarios where you need to manage an existing WordPress installation without restructuring its directory layout.

## Requirements

- PHP >= 8.1
- Composer
- **rsync** - Used to sync WordPress core files from vendor to public directory

## Why WP Boot?

While robust solutions like [Bedrock](https://roots.io/bedrock/), [WP Starter](https://github.com/wecodemore/wpstarter), and [Wordplate](https://github.com/vinkla/wordplate) offer excellent WordPress management through Composer, they typically require significant structural changes to the WordPress directory layout. 

WP Boot was created for situations where:

- You're working with an **existing WordPress installation** that cannot be heavily modified
- You need to **version control** an already-deployed WordPress site
- You want to **dockerize** a traditional WordPress setup without restructuring
- You need a quick, minimal-impact solution for dependency management

## How It Works

WP Boot uses **rsync** to synchronize WordPress core files from the Composer vendor directory to your public directory, keeping the standard WordPress structure intact.

It only modifies the `wp-config.php` file, adding a simple bootstrap block:

```php
// BEGIN WP Boot - Do not remove this block
// @see https://github.com/wp-spaghetti/wp-boot
use function Env\env;

require_once dirname(__DIR__).'/private/wp-boot/bootstrap.php';
// END WP Boot - Do not remove this block

define('DB_NAME', env('DB_NAME'));
define('DB_USER', env('DB_USER'));
define('DB_PASSWORD', env('DB_PASSWORD'));
define('DB_HOST', env('DB_HOST'));
```

This approach allows you to:

- Manage WordPress core, plugins, and themes via Composer
- Use environment variables for configuration (`.env` files)
- Keep the standard WordPress directory structure intact

## Installation

```bash
composer create-project wp-spaghetti/wp-boot private/wp-boot
cd private/wp-boot
cp .env.dist .env
# Edit .env with your configuration
```

Then add the bootstrap block to your `wp-config.php` file (see "How It Works" section above).

### Directory Structure

After installation, your project structure will look like this:

```
your-project/
├── private/
│   └── wp-boot/
│       ├── vendor/
│       │   └── wordpress/          # WordPress core managed by Composer
│       ├── .env                     # Environment configuration
│       ├── bootstrap.php
│       ├── composer.json
│       └── post-cmd.sh              # rsync sync script
└── public/                          # Your WordPress public directory
    ├── wp-admin/                    # Synced from vendor/wordpress
    ├── wp-includes/                 # Synced from vendor/wordpress
    ├── wp-content/
    │   ├── plugins/                 # Managed by Composer
    │   ├── themes/                  # Managed by Composer
    │   └── uploads/                 # User uploads (not managed)
    ├── wp-config.php                # Modified to include bootstrap
    └── index.php                    # Synced from vendor/wordpress
```

The `post-cmd.sh` script automatically syncs WordPress core files from `private/wp-boot/vendor/wordpress/` to `public/` after every `composer install` or `composer update`.

## Optional: Installing Language Packs

WordPress core and plugins can be installed in different languages using Composer.

**1. Add the language repository to `composer.json`:**
```json
{
  "repositories": [
    {
      "type": "composer",
      "url": "https://wp-languages.github.io",
      "only": [
        "koodimonni-language/*",
        "koodimonni-plugin-language/*",
        "koodimonni-theme-language/*"
      ]
    }
  ]
}
```

**2. Add dropin paths to `extra` in `composer.json`:**
```json
{
  "extra": {
    "dropin-paths": {
      "../../public/wp-content/languages/": [
        "vendor:koodimonni-language"
      ],
      "../../public/wp-content/languages/plugins/": [
        "vendor:koodimonni-plugin-language"
      ],
      "../../public/wp-content/languages/themes/": [
        "vendor:koodimonni-theme-language"
      ]
    }
  }
}
```

**3. Install language packs:**
```bash
# WordPress core in Italian
composer require koodimonni-language/core-it_it

# All translations for Italian
composer require koodimonni-language/it_it
```

**4. Configure WordPress to use the language in `.env`:**
```env
WPLANG=it_IT
```

For more information: https://wp-languages.github.io

## Optional: Disallow Search Engine Indexing in Non-Production

WordPress 5.5+ includes native environment detection via `WP_ENVIRONMENT_TYPE`. Wp-boot automatically sets this based on your `WP_ENV` value in `.env`.

To prevent search engines from indexing staging/development sites, create this file:

**`public/wp-content/mu-plugins/disallow-indexing.php`**
```php
<?php
/**
 * Plugin Name: Disallow Indexing (Non-Production)
 * Description: Automatically disallows search engine indexing in non-production environments
 */

if (wp_get_environment_type() !== 'production' && !is_admin()) {
    add_action('pre_option_blog_public', '__return_zero');
}
```

This automatically sets "Discourage search engines" in Settings → Reading for non-production environments.

## When NOT to Use WP Boot

For new projects or when you have full control over the infrastructure, consider these more robust alternatives:

- **[Bedrock](https://roots.io/bedrock/)** - Modern WordPress stack with improved folder structure
- **[WP Starter](https://github.com/wecodemore/wpstarter)** - Composer-based WordPress setup with flexible configuration
- **[Wordplate](https://github.com/vinkla/wordplate)** - Modern WordPress stack with Laravel-inspired structure
- **[WordPress Project](https://github.com/johnpbloch/wordpress-project)** - Minimal Composer-based WordPress installer

## References

- [Research: Bedrock vs WP Starter](https://discourse.roots.io/t/research-bedrock-vs-wp-starter-by-gmazzap/14044/4)
- [Installing WordPress via Composer](https://wp-yoda.com/en/wordpress/installing-wordpress-via-composer/)
- [Installing WordPress in separate directory via Composer](https://github.com/renakdup/installing-wordpress-in-separate-directory-via-composer)
- [Gist by gemmadlou](https://gist.github.com/gemmadlou/6fc40583318430f77eda54ebea91c2a1)

## Changelog

Please see [CHANGELOG](CHANGELOG.md) for a detailed list of changes for each release.

We follow [Semantic Versioning](https://semver.org/) and use [Conventional Commits](https://www.conventionalcommits.org/) to automatically generate our changelog.

### Release Process

- **Major versions** (1.0.0 → 2.0.0): Breaking changes
- **Minor versions** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch versions** (1.0.0 → 1.0.1): Bug fixes, backward compatible

All releases are automatically created when changes are pushed to the `main` branch, based on commit message conventions.

## Contributing

For your contributions please use:

- [Conventional Commits](https://www.conventionalcommits.org)
- [git-flow workflow](https://danielkummer.github.io/git-flow-cheatsheet/)
- [Pull request workflow](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)

See [CONTRIBUTING](.github/CONTRIBUTING.md) for detailed guidelines.

## Sponsor

[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="200" alt="Buy Me A Coffee">](https://buymeacoff.ee/frugan)

## License

(ɔ) Copyleft 2025 [Frugan](https://frugan.it).  
[GNU GPLv3](https://choosealicense.com/licenses/gpl-3.0/), see [LICENSE](LICENSE) file.

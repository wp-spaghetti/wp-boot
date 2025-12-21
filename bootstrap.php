<?php

declare(strict_types=1);

/*
 * This file is part of the WP Boot package.
 *
 * (ɔ) Frugan <dev@frugan.it>
 *
 * This source file is subject to the GNU GPLv3 or later license that is bundled
 * with this source code in the file LICENSE.
 */

use Env\Env;

use function Env\env;

define('WP_BOOT_ROOT', __DIR__);

require __DIR__.'/vendor/autoload.php';

/**
 * Copy custom variables from $_SERVER to $_ENV for PHP-FPM clear_env=yes compatibility.
 *
 * When using Docker with PHP-FPM and `clear_env = yes` (default),
 * environment variables passed via Docker and defined in `environment.conf`
 * (e.g. /etc/php/*\/fpm/pool.d/www.conf or /opt/bitnami/php/etc/environment.conf w/ Bitnami)
 * are only injected into the $_SERVER superglobal — not into $_ENV or via getenv().
 *
 * This happens especially when `variables_order = GPCS` (default w/ Bitnami), which excludes `E` (ENV).
 * All environment variables received by PHP are strings; type casting is handled manually by the Env library.
 *
 * @see https://github.com/oscarotero/env/pull/6
 * @see https://www.php.net/manual/en/function.getenv.php
 * @see https://jolicode.com/blog/what-you-need-to-know-about-environment-variables-with-php
 * @see https://stackoverflow.com/a/42389720/3929620
 *
 * @param array $prefixes   If empty, copy from start until first system variable.
 *                          If not empty, copy only variables with these prefixes.
 * @param array $systemVars System variables that act as "stop" when $prefixes is empty
 *
 * @return array Copied variables
 */
function fixMissingEnvVars(
    array $prefixes = [],
    array $systemVars = ['PATH', 'USER', 'HOME', 'SHELL', 'PWD']
): array {
    // If variables_order includes 'E', $_ENV is already populated
    if (str_contains(ini_get('variables_order') ?: '', 'E')) {
        return [];
    }

    $copied = [];

    if (empty($prefixes)) {
        // Sequential mode: copy from start until first system variable
        foreach ($_SERVER as $key => $value) {
            // If we encounter a system variable, stop
            if (in_array($key, $systemVars, true)) {
                break;
            }

            // Copy the variable if it doesn't already exist in $_ENV
            if (!isset($_ENV[$key])) {
                $_ENV[$key] = $value;
                $copied[$key] = $value;
            }
        }
    } else {
        // Prefix mode: copy only variables with specific prefixes
        foreach ($_SERVER as $key => $value) {
            // Skip system variables
            if (in_array($key, $systemVars, true)) {
                continue;
            }

            // Check if the variable starts with one of the allowed prefixes
            foreach ($prefixes as $prefix) {
                if (str_starts_with($key, $prefix) && !isset($_ENV[$key])) {
                    $_ENV[$key] = $value;
                    $copied[$key] = $value;

                    break;
                }
            }
        }
    }

    return $copied;
}

fixMissingEnvVars(systemVars: []);

// USE_ENV_ARRAY + CONVERT_* + STRIP_QUOTES
Env::$options = 31;

$suffix = '';
$env = '.env';
$envs = [$env];

if (defined('_APP_ENV')) {
    $suffix .= '.'._APP_ENV;
    $envs[] = $env.$suffix;
}

// docker -> minideb
if (!empty($_SERVER['APP_ENV'])) {
    $suffix .= '.'.$_SERVER['APP_ENV'];
    $envs[] = $env.$suffix;
}

$envs = array_unique(array_filter($envs));

try {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__, $envs, false);
    $dotenv->load();
    $dotenv->required(['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']);

    // https://github.com/vlucas/phpdotenv/issues/231#issuecomment-663879815
    foreach ($_ENV as $key => $val) {
        if (ctype_digit((string) $val)) {
            $dotenv->required($key)->isInteger();
            $_ENV[$key] = (int) $val;
        } elseif (!empty($val) && !is_numeric($val) && ($newVal = filter_var($_ENV[$key], \FILTER_VALIDATE_BOOLEAN, \FILTER_NULL_ON_FAILURE)) !== null) {
            $dotenv->required($key)->isBoolean();
            $_ENV[$key] = $newVal;
        } elseif (empty($val) || 'null' === mb_strtolower((string) $val, 'UTF-8')) {
            $_ENV[$key] = null;
        }
    }
} catch (Exception $e) {
    // https://github.com/phpro/grumphp/blob/master/doc/tasks/phpparser.md#no_exit_statements
    exit($e->getMessage());
}

/**
 * Set WordPress environment type based on WP_ENV
 * Uses WordPress 5.5+ native WP_ENVIRONMENT_TYPE
 * Accepted values: 'local', 'development', 'staging', 'production'
 */
$wp_env = env('WP_ENV') ?: 'production';
if (!defined('WP_ENVIRONMENT_TYPE') && in_array($wp_env, ['local', 'development', 'staging', 'production'], true)) {
    define('WP_ENVIRONMENT_TYPE', $wp_env);
}

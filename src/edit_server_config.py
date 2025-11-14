#!/usr/bin/env python3

"""
Edit Project Zomboid server config.

Supports:
  - Single key get/set:
      edit_server_config.py <config_file> <key> [<value>]
  - Bulk update from env (PZ_*):
      edit_server_config.py --bulk-from-env <config_file>
"""

import os
import sys
from configparser import RawConfigParser


def save_config(config: RawConfigParser, config_file: str) -> None:
    with open(config_file, "w", encoding="utf-8") as file:
        config.write(file, space_around_delimiters=False)


def ensure_section_header(config_file: str) -> None:
    try:
        with open(config_file, "r+", encoding="utf-8") as file:
            lines = file.readlines()
            if not lines:
                file.write("[ServerConfig]\n")
                return
            if lines[0].strip() != "[ServerConfig]":
                file.seek(0)
                file.write("[ServerConfig]\n")
                for line in lines:
                    file.write(line)
    except FileNotFoundError:
        with open(config_file, "w", encoding="utf-8") as file:
            file.write("[ServerConfig]\n")


def load_config(config_file: str) -> RawConfigParser:
    ensure_section_header(config_file)
    cp: RawConfigParser = RawConfigParser()
    cp.optionxform = lambda option: option  # keep key case
    read_files = cp.read(config_file, encoding="utf-8")
    if read_files:
        if "ServerConfig" not in cp:
            cp["ServerConfig"] = {}
        return cp
    else:
        raise TypeError("Config file is invalid!")


def check_server_config_file(config_file: str) -> bool:
    try:
        with open(config_file, "r", encoding="utf-8"):
            return True
    except FileNotFoundError:
        sys.stderr.write(f"{config_file} not found!\n")
        return False


def bulk_update_from_env(config_file: str, prefix: str = "PZ_") -> None:
    if not check_server_config_file(config_file):
        ensure_section_header(config_file)

    config = load_config(config_file)
    server_section = config["ServerConfig"]

    updated = False
    for env_key, env_value in os.environ.items():
        if not env_key.startswith(prefix):
            continue
        key = env_key[len(prefix) :]
        if not key:
            continue
        server_section[key] = env_value
        updated = True

    if updated:
        save_config(config, config_file)
        print(f"Updated {config_file} from environment (prefix '{prefix}').")
    else:
        print(f"No {prefix}* environment variables found; nothing to update.")


def usage() -> None:
    print(
        "Usage:\n"
        "  edit_server_config.py <config_file> <key> [<value>]\n"
        "  edit_server_config.py --bulk-from-env <config_file>\n"
    )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)

    if sys.argv[1] == "--bulk-from-env":
        if len(sys.argv) != 3:
            usage()
            sys.exit(1)
        config_file = sys.argv[2]
        bulk_update_from_env(config_file)
        sys.exit(0)

    if len(sys.argv) < 3 or len(sys.argv) > 4:
        usage()
        sys.exit(1)

    config_file: str = sys.argv[1]
    key: str = sys.argv[2]

    if not check_server_config_file(config_file):
        sys.exit(1)

    config: RawConfigParser = load_config(config_file)

    if len(sys.argv) == 3:
        if "ServerConfig" in config and key in config["ServerConfig"]:
            print(f"{config['ServerConfig'][key]}")
    else:
        value: str = sys.argv[3]
        config["ServerConfig"][key] = value
        save_config(config, config_file)
#!/usr/bin/env python3
"""
Output status information to a Unicorn HAT HD LED display.
"""
import sys
import data  # functions that generate row content
from matrix_display.displays import UnicornHATHD
from matrix_display import Conveyor


def main(json_status_file):
    """
    Configure and start a matrix_display Conveyor.

    Parameters
    ----------
    json_status_file : str
        Path to JSON file to periodically parse for current status information.
    """
    data.status_file = json_status_file
    conveyor = Conveyor(UnicornHATHD(16, 16).rotation(180))
    conveyor.add_row(data.get_wifi_info, 3)  # 3 second refresh
    conveyor.add_row(data.get_lan_info, 3)  # 3 second refresh
    conveyor.add_row(data.get_internet_info, 3)  # 3 second refresh
    conveyor.play()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit('Missing parameter for JSON status file path')
    else:
        main(sys.argv[1])

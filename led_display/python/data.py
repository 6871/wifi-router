#!/usr/bin/env python3
"""
Module defining functions to return row data the matrix_display package can
show on an LED display.
"""
import json
from matrix_display import rgb_colours as rgb

status_file = None


def get_data(json_status_file):
    """
    Helper function to extract main items from the JSON status file.
    """
    with open(json_status_file) as jsf:
        j = json.load(jsf)

        ssid = j['ssid']
        lan_link = j['lan']
        internet_state = j['internet']
        lan_ipv4 = ""
        wifi_ipv4 = ""

        for iface in j['ip']:
            for family in iface['addr_info']:
                if family['family'] == 'inet':
                    if iface['ifname'] == 'eth0':
                        lan_ipv4 = family['local']
                    elif iface['ifname'] == 'wlan0':
                        wifi_ipv4 = family['local']

        return {
            'ssid': ssid,
            'lan_link': lan_link,
            'internet_state': internet_state,
            'lan_ipv4': lan_ipv4,
            'wifi_ipv4': wifi_ipv4
        }


def get_wifi_info():
    """
    Return Wi-Fi SSID and IP address row for matrix_display.
    """
    d = get_data(status_file)
    return [(f"WiFi SSID={d['ssid']} {d['wifi_ipv4']}", rgb.green)]


def get_lan_info():
    """
    Return LAN link info row for matrix_display; link state changes colour.
    """
    d = get_data(status_file)
    link_rgb = rgb.orange

    if d['lan_link'] == 'UP':
        link_rgb = rgb.lime

    return [
        (f"LAN link={d['lan_link']}", link_rgb),
        (f" ipv4={d['lan_ipv4']}", rgb.teal)
    ]


def get_internet_info():
    """
    Return internet state row for matrix_display; red if DOWN, lime if UP.
    """
    d = get_data(status_file)
    colour = rgb.red

    if d['internet_state'] == 'UP':
        colour = rgb.lime

    return [(f"internet={d['internet_state']}", colour)]

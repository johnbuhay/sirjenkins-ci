#!/usr/bin/env python

import json

with open('package.json') as package_json:
    data = json.load(package_json)
    print data['version']
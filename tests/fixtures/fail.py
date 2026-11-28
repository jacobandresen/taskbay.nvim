#!/usr/bin/env python3
"""Fault injection in front of a command (gh, git) on the PATH.

Installed as a small shell script named like the command, which runs:
    fail.py <wrapper dir> <command> <args...>

TASKBAY_FAIL lists commands to fail, separated by ";": "gh issue close" fails every
matching call, "git commit@2" only the second one. A failed call prints "injected failure"
and exits 1. TASKBAY_SLOW lists commands to delay, written the same way with a delay:
"git status=500ms". Every call that is not failed runs the next program of the same name on
the PATH after the wrapper directory, unchanged. Leading options (git -C <dir>, -c <k=v>, ...)
are ignored when matching.
"""
import fcntl
import json
import os
import sys
import time

wrapper_dir, name, args = os.path.realpath(sys.argv[1]), sys.argv[2], sys.argv[3:]


def words(argv):
    found, skip = [], False
    for arg in argv:
        if skip:
            skip = False
        elif not found and arg in ("-C", "-c"):
            skip = True
        elif not found and arg.startswith("-"):
            continue
        else:
            found.append(arg)
    return found


def matches(spec):
    parts = spec.split()
    return bool(parts) and parts[0] == name and words(args)[: len(parts) - 1] == parts[1:]


def count(spec):
    """Number of matching calls so far, this one included, across processes."""
    path = os.path.join(wrapper_dir, ".counts.json")
    with open(path, "a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        counts = json.loads(handle.read() or "{}")
        counts[spec] = counts.get(spec, 0) + 1
        handle.seek(0)
        handle.truncate()
        handle.write(json.dumps(counts))
        return counts[spec]


def entries(variable):
    return [entry.strip() for entry in os.environ.get(variable, "").split(";") if entry.strip()]


for entry in entries("TASKBAY_SLOW"):
    spec, _, delay = entry.rpartition("=")
    if matches(spec):
        time.sleep(float(delay.removesuffix("ms")) / 1000)

for entry in entries("TASKBAY_FAIL"):
    spec, at, nth = entry.partition("@")
    if matches(spec) and (not at or count(entry) == int(nth)):
        sys.stderr.write("injected failure: %s %s\n" % (name, " ".join(args)))
        sys.exit(1)

for directory in os.environ.get("PATH", "").split(os.pathsep):
    if directory and os.path.realpath(directory) != wrapper_dir:
        candidate = os.path.join(directory, name)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            os.execv(candidate, [candidate] + args)
sys.exit("fail.py: no %s on the PATH after %s" % (name, wrapper_dir))

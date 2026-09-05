"""Exercise the sourced Warp hooks (Bash/Zsh, Fish) with real interactive and noninteractive PTYs."""
import os
from pathlib import Path
import pty
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]


def run_pty(args, env):
    master, slave = pty.openpty()
    try:
        process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave, env=env)
        os.close(slave)
        output = b''
        while True:
            try:
                data = os.read(master, 4096)
            except OSError:
                break
            if not data:
                break
            output += data
        status = process.wait(timeout=10)
    finally:
        os.close(master)
    return status, output


def make_env(root):
    env = os.environ.copy()
    for key in ('FOXLY_MOTD_WARP_TTY', 'BASH_ENV', 'ENV'):
        env.pop(key, None)
    env.update(HOME=str(root), FOXLY_MOTD_ROOT=str(root),
                TERM_PROGRAM='WarpTerminal', SSH_CONNECTION='192.0.2.1 1 192.0.2.2 22',
                SSH_TTY='/dev/pts/42', WARP_BOOTSTRAPPED='1')
    return env


def write_cli(root):
    cli = root / "usr/local/sbin/foxly-motd"
    cli.parent.mkdir(parents=True)
    cli.write_text('#!/bin/sh\necho FOXLY_RENDERED\n')
    cli.chmod(0o755)


def exercise_posix(shell):
    """Bash and Zsh share the same hook file and [[ ]] test syntax."""
    hook = project / "libexec/foxly-motd-warp"
    with tempfile.TemporaryDirectory(prefix=f"foxly-warp-{shell}-") as directory:
        root = Path(directory)
        write_cli(root)
        base = make_env(root)
        if shell == 'zsh':
            zdotdir = root / 'zdotdir'
            zdotdir.mkdir()
            rc = zdotdir / '.zshrc'
            base['ZDOTDIR'] = str(zdotdir)
            respawn = f'ZDOTDIR="{zdotdir}" zsh -ic :'
        else:
            rc = root / 'rc'
            respawn = f'bash --noprofile --rcfile "{rc}" -ic :'
        rc.write_text(f'. "{hook}"\n')

        def args(interactive, command):
            if shell == 'zsh':
                return ['zsh'] + (['-ic'] if interactive else ['-c']) + [command]
            base_args = ['bash', '--noprofile', '--rcfile', str(rc)]
            return base_args + (['-ic'] if interactive else ['-c']) + [command]

        def check(name, changes=None, interactive=True, command=':', expected=0):
            env = base | (changes or {})
            status, output = run_pty(args(interactive, command), env)
            assert status == 0 and output.count(b'FOXLY_RENDERED') == expected, (shell, name, output)
            print(f'PASS [{shell}]:', name)

        source_cmd = f'. "{rc}"'
        check('Warp renders once, including repeated sourcing and child shells',
              command=f'{source_cmd}; {respawn}', expected=1)
        check('standard terminal is quiet', {'TERM_PROGRAM': 'Apple_Terminal'})
        check('local Warp is quiet', {'SSH_CONNECTION': ''})
        check('missing SSH terminal is quiet', {'SSH_TTY': ''})
        check('new SSH terminal renders despite inherited marker',
              {'FOXLY_MOTD_WARP_TTY': '/dev/pts/41'}, expected=1)
        check('noninteractive commands are quiet', interactive=False, command=source_cmd)
        (root / '.hushlogin').touch()
        check('hushlogin is respected')


def exercise_fish():
    hook = project / "libexec/foxly-motd-warp.fish"
    with tempfile.TemporaryDirectory(prefix="foxly-warp-fish-") as directory:
        root = Path(directory)
        write_cli(root)
        base = make_env(root)
        confdir = root / 'xdgcfg' / 'fish'
        confdir.mkdir(parents=True)
        rc = confdir / 'config.fish'
        rc.write_text(f'source "{hook}"\n')
        base['XDG_CONFIG_HOME'] = str(root / 'xdgcfg')

        def check(name, changes=None, interactive=True, command=':', expected=0):
            env = base | (changes or {})
            args = ['fish'] + (['-i', '-c'] if interactive else ['-c']) + [command]
            status, output = run_pty(args, env)
            assert status == 0 and output.count(b'FOXLY_RENDERED') == expected, ('fish', name, output)
            print('PASS [fish]:', name)

        source_cmd = f'source "{rc}"'
        check('Warp renders once, including repeated sourcing and child shells',
              command=f'{source_cmd}; fish -i -c :', expected=1)
        check('standard terminal is quiet', {'TERM_PROGRAM': 'Apple_Terminal'})
        check('local Warp is quiet', {'SSH_CONNECTION': ''})
        check('missing SSH terminal is quiet', {'SSH_TTY': ''})
        check('new SSH terminal renders despite inherited marker',
              {'FOXLY_MOTD_WARP_TTY': '/dev/pts/41'}, expected=1)
        check('noninteractive commands are quiet', interactive=False, command=source_cmd)
        (root / '.hushlogin').touch()
        check('hushlogin is respected')


exercise_posix('bash')
exercise_posix('zsh')
exercise_fish()

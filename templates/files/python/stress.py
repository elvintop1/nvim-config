import subprocess


def run(cmd: str, stdin=None) -> bytes:
    return subprocess.check_output(cmd, shell=True, stdin=stdin)


if __name__ == "__main__":
    test = 1
    while True:
        with open("input.txt", "wb") as f:
            f.write(run("python gen.py"))

        with open("input.txt", "rb") as f:
            brute = run("python brute.py", stdin=f)
        with open("input.txt", "rb") as f:
            main = run("python main.py", stdin=f)

        if brute != main:
            print(f"Mismatch on test {test}")
            break
        print(f"Passed test {test}")
        test += 1

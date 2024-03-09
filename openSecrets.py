import os
import subprocess
import signal
from typing import Optional

class SyncManager:
    def __init__(self) -> None:
        self.cryfs_process: Optional[subprocess.Popen] = None
        # Register signal handlers for clean exit
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def start_cryfs(self) -> bool:
        try:
            self.cryfs_process = subprocess.Popen(["cryfs", "--foreground", "/home/bakhtiyar/OneDrive/mezar", "secrets"])
        except Exception as e:
            print(f"Failed to start cryfs: {e}")
            self.cryfs_process = None
            return False
        return True

    def sync(self) -> bool:
        print("Synchronizing OneDrive...")
        return os.system("onedrive --synchronize") == 0

    def cleanup(self) -> None:

        if self.cryfs_process:
            print("Terminating cryfs...")
            self.cryfs_process.terminate()  # Send SIGTERM
            try:
                # Wait up to 10 seconds for cryfs to terminate
                self.cryfs_process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                print("cryfs did not terminate in time; sending SIGKILL.")
                self.cryfs_process.kill()  # Force termination
                self.cryfs_process.wait()  # Ensure process is terminated
            except Exception as e:
                print(f"Error during cryfs termination: {e}")
        if self.sync():
            print("OneDrive synchronized successfully.")
        else:
            print("Failed to synchronize OneDrive. Exiting.")



    def signal_handler(self, signal_received: int, frame: Optional[object]) -> None:
        # Handle cleanup actions before exiting
        print(f"Signal {signal_received} received, cleaning up...")
        self.cleanup()
        exit(0)  # Exit the program

def main() -> None:
    manager = SyncManager()
    if not manager.sync():
        print("Failed to synchronize OneDrive. Continuing...")


    if manager.start_cryfs():
        print("cryfs started successfully.")
        # The script will now handle termination signals and ensure cleanup is done properly.
    else:
        print("Failed to start cryfs. Please check the error messages.")

    # Keep the script running until it receives a termination signal
    signal.pause()

if __name__ == "__main__":
    main()

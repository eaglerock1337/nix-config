# rpi5 quickstart

## Cross-arch install bootstrap

```bash
sudo apt install qemu-user-static binfmt support
sudo update-binfmts --enable qemu-aarch64
echo "extra-platforms = aarch64-linux" | sudo tee -a /etc/nix/nix.conf
```

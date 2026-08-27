# Specifications
https://www.usb.org/hid
https://www.usb.org/document-library/device-class-definition-hid-111
https://www.usb.org/sites/default/files/hid1_11.pdf
https://usb.org/document-library/hid-usage-tables-122
https://www.usb.org/sites/default/files/hut1_22.pdf

# HID Dump
https://github.com/DIGImend/usbhid-dump

# HID Parse
https://github.com/DIGImend/hidrd

# Usage Tables JSON

USB-IF publishes the HID Usage Tables only as a PDF (`hut1_*.pdf`) with the JSON
embedded as an attachment — there is no standalone JSON download URL. We mirror
the extracted JSON from a pinned commit of `microsoft/mu_rust_hid` (an unmodified
copy of the official file) instead of extracting it from the PDF at build time:

https://github.com/microsoft/mu_rust_hid/blob/23283fc00647cbf204fc72d5bc83a837cf58c42c/examples/resources/HidUsageTables.json

It is fetched into `priv/static/HidUsageTables.json` by
`Mix.Tasks.HidParser.FetchUsageTables` (wired into `mix compile` via an alias).

# Scripts
```
sudo usbhid-dump -d 046a:00b0 -i 0 \
    | tee cherry_keyboard.hid.hex \
    | grep -v : | xxd -r -p \
    | tee cherry_keyboard.hid.bin \
    | hidrd-convert -o spec \
    | tee cherry_keyboard.hid.spec
```

# Enums

## 4.2 Subclass

### Subclass Codes

The `bInterfaceSubClass` member declares whether a device supports a boot interface, otherwise it is `0`.

| Subclass Code  | Description             |
|----------------|-------------------------|
| `0`            | No Subclass             |
| `1`            | Boot Interface Subclass |
| `2` - `255`    | Reserved                |

## 4.3 Protocols

A variety of protocols are supported HID devices. The `bInterfaceProtocol` member of an Interface descriptor only has
meaning if the `bInterfaceSubClass` member declares that the device supports a boot interface, otherwise it is `0`.

### Protocol Codes

| Protocol Code | Description |
|---------------|-------------|
| `0`           | None        |
| `1`           | Keyboard    |
| `2`           | Mouse       |
| `3` - `255`   | Reserved    |
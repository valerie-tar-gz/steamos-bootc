# Arch Linux Bootc

Experiment to see if Bootc could work on Arch Linux. And it does! With the composefs-backend :)

<img width="2305" height="846" alt="image" src="https://github.com/user-attachments/assets/f496a2f4-0782-408c-b207-c7acdde2e5ac" />

This is not completely functional yet! Seems that dbus has some trouble running in this environment. But its Arch! Its Bootc! Its cool!
Now you can be even cooler and say that you are using Arch BTW while not having your system break all the time! :)

## Building

In order to get a running arch-bootc system you can run the following steps:
```shell
just build-containerfile # This will build the containerfile and all the dependencies you need
just generate-bootable-image # Generates a bootable image for you using bootc!
```

Then you can run the `bootable.img` as your boot disk in your preferred hypervisor.

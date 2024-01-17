# UniversalUseToPickUp
 
A very simple minimod for GZDoom that adds 3 features:
* Items can be picked up by pressing Use (walking over them does nothing)
* The item you can pick up is highlighted
* Picking is animated (the item is pulled into you on pickup)

The pickup range is x1.5 of the default. The aiming behavior requires aiming at the item, but there's about a 20-degree leeway, so you don't have to look at it exactly. If several items match the criteria, the one closest to your crosshair will be prioritized.

Feel free to use in your projects or fork, just give credit.

For a much more robust implementation of a similar idea with different handling, see https://github.com/argv-minus-one/gzdoom-use-to-pickup.

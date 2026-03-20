// Created by LunarEclipse on 2026-03-19 17:03.

using Godot;

public partial class PlatformerCharacter2D
{
    public partial void InteractWith(Node node)
    {
        if (node is LaserBeam laser)
        {
            Die();
        }
    }
}
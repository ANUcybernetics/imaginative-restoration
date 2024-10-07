# each element is (inital_frame, scene description, prompt)
FRAME_PROMPT_INDEX = [
    # TODO need to update the frame indices for all of these when we get the final cut...
    (1, "small white house: flying above the trees", "Small winged animal"),
    (1, "small white house: flying above the trees", "Large winged animal"),
    (1, "small white house: flying above the trees", "Feathers"),
    (1, "small white house: flying above the trees", "Beaks"),
    (1, "small white house: flying above the trees", "Small scaly creature"),
    (1, "small white house: flying above the trees", "Crawling insect"),
    (1, "small white house: flying above the trees", "Winged insect"),

    (2, "water spout", "Small swimming creature"),
    (2, "water spout", "Fins"),
    (2, "water spout", "tail"),

    (3, "fish in water", "Large scaly creature"),
    (3, "fish in water", "Reptile"),
    (3, "fish in water", "Small swimming creature"),
    (3, "fish in water", "Small flying insect"),
    (3, "fish in water", "Large wings"),
    (3, "fish in water", "Small winged creature"),
    (3, "fish in water", "Feathers"),

    (4, "the boat", "Large swimming creature"),
    (4, "the boat", "Fins"),
    (4, "the boat", "Tail"),
    (4, "the boat", "Sharp teeth"),
    (4, "the boat", "Large tentacles"),
    (4, "the boat", "Large winged creature"),
    (4, "the boat", "Feathers"),
    (4, "the boat", "Beak"),

    (5, "underwater ballet", "Small scaly creature"),
    (5, "underwater ballet", "Swimming"),
    (5, "underwater ballet", "Smooth"),
    (5, "underwater ballet", "Flowing"),
    (5, "underwater ballet", "Gliding"),
    (5, "underwater ballet", "Fins"),
    (5, "underwater ballet", "Tail"),

    (6, "wider shot UW ballet", "Large scaly creature"),
    (6, "wider shot UW ballet", "Glowing"),
    (6, "wider shot UW ballet", "Fins"),
    (6, "wider shot UW ballet", "Long tail"),
    (6, "wider shot UW ballet", "Sharp teeth"),
    (6, "wider shot UW ballet", "Smooth skin"),

    (7, "UW ballet dancer swimming on her back", "Long flowing"),
    (7, "UW ballet dancer swimming on her back", "Smooth"),
    (7, "UW ballet dancer swimming on her back", "Leaves"),
    (7, "UW ballet dancer swimming on her back", "Reeds"),
    (7, "UW ballet dancer swimming on her back", "Bright colours"),
    (7, "UW ballet dancer swimming on her back", "Sharp"),
    (7, "UW ballet dancer swimming on her back", "Curved shapes"),
    (7, "UW ballet dancer swimming on her back", "Drifting"),

    (8, "UW dancer sea floor", "Small swimming creature"),
    (8, "UW dancer sea floor", "Smooth"),
    (8, "UW dancer sea floor", "Scaly"),
    (8, "UW dancer sea floor", "Green"),
    (8, "UW dancer sea floor", "Brown"),
    (8, "UW dancer sea floor", "Floating"),
    (8, "UW dancer sea floor", "Gliding"),
    (8, "UW dancer sea floor", "Large swimming creature"),
    (8, "UW dancer sea floor", "Big eyes"),

    (9, "the fisherman", "Small swimming creature"),
    (9, "the fisherman", "Jumping creature"),
    (9, "the fisherman", "Smooth"),
    (9, "the fisherman", "Fins"),
    (9, "the fisherman", "Tail"),
    (9, "the fisherman", "Large tentacles"),
    (9, "the fisherman", "Strong"),
    (9, "the fisherman", "Large"),

    (10, "Children at the beach", "Scurrying creature"),
    (10, "Children at the beach", "Leafy plants"),
    (10, "Children at the beach", "Green"),
    (10, "Children at the beach", "Large winged creature"),

    (11, "Children with tire on main beach", "Large winged creature"),
    (11, "Children with tire on main beach", "Feathers"),
    (11, "Children with tire on main beach", "Beaks"),
    (11, "Children with tire on main beach", "Long claws"),
    (11, "Children with tire on main beach", "Smooth"),
    (11, "Children with tire on main beach", "Underground insect"),
    (11, "Children with tire on main beach", "Claws"),
    (4000, "Children with tire on main beach", "Scurrying creature"),
]

def for_frame(frame_index):
    for index, _, prompt in FRAME_PROMPT_INDEX:
        if index >= frame_index:
            return prompt + ", matisse, fauvism, cave painting, vibrant colors, bold outline, (isolated on greenscreen: 1.5), sfx, greenscreen"

    raise f"cannot find prompt for frame {frame_index}: index out of bounds"

package main
import rl "vendor:raylib"
import "core:fmt"

WINDOW_WIDTH  :: 1200
WINDOW_HEIGHT :: 800
CARD_TEXTURE_RECTANGLE :: rl.Rectangle{0, 0, 500, 725}
CARD_WIDTH :: 120.0
CARD_HEIGHT :: 174.0
PILES_PADDING :: 30.0
FOUNDATION_PADDING :: 30.0
FOUNDATION_VERT_PADDING :: CARD_HEIGHT / 6.0
BG_COLOR :: rl.Color{0x18, 0xa0, 0x18, 0x88}
EMPTY_CARD_VALUE :: Card_Value(-1)
card_textures : map[string]rl.Texture

Game_State :: struct {
    piles	  : [7]Pile,
    foundations   : [4]Card,
    stock	  : [dynamic]Card,
    waste	  : [dynamic]Card,
    hovered_data  : Hovered_Data,
    clicked_data  : Clicked_Data,
}

Board_Location :: enum {
    None = 0,
    Stock,
    Waste,
    Piles,
    Foundation,
}

Hovered_Data :: struct {
    loc		: Board_Location,
    id		: int,
    depth	: int,
}
Clicked_Data :: struct {
    offset             : rl.Vector2,
    using hovered_data : Hovered_Data,
}

game_state : Game_State
game_init :: proc()
{
    for suit in Card_Suit do for val in Card_Value do append(&game_state.stock, card_create(val, suit))
    for i in 0..<7 {
	for j in i..<7 {
	    append(&game_state.piles[j].cards, pop(&game_state.stock))
	}
	game_state.piles[i].n_of_face_down = i
    }
    for &f, i in game_state.foundations {
	f.suit = Card_Suit(i+1)
	f.value = EMPTY_CARD_VALUE
    }
}

game_destroy :: proc()
{
    for pile in game_state.piles do delete(pile.cards)
    delete(game_state.stock)
    delete(game_state.waste)
}

Pile :: struct {
    cards          : [dynamic]Card,
    n_of_face_down : int,
}

Card :: struct {
    value  : Card_Value, 
    suit    : Card_Suit,
    texture : rl.Texture,
}

Card_Value :: enum {
    Ace,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
}
Card_Suit :: enum {
    Clubs,
    Diamonds,
    Hearts,
    Spades,
}

card_create :: proc(value: Card_Value, suit: Card_Suit) -> Card {
    return Card{value = value, suit = suit, texture = card_textures[card_filename(value, suit)]}
}

card_filename :: proc(value: Card_Value, suit: Card_Suit) -> string {
    suit_names := [Card_Suit]string{
	    .Clubs = "clubs",
	    .Diamonds = "diamonds",
	    .Hearts = "hearts",
	    .Spades = "spades",
    }
    value_names := [Card_Value]string{
	    .Two	= "2",
	    .Three	= "3",
	    .Four	= "4",
	    .Five	= "5",
	    .Six	= "6",
	    .Seven	= "7",
	    .Eight	= "8",
	    .Nine	= "9",
	    .Ten	= "10",
	    .Jack	= "jack",
	    .Queen	= "queen",
	    .King	= "king",
	    .Ace	= "ace",
    }
    if value >= .Jack do return fmt.tprintf("%s_of_%s2.png", value_names[value], suit_names[suit])
    else do return fmt.tprintf("%s_of_%s.png", value_names[value], suit_names[suit])
}

load_card_textures :: proc() -> bool {
    folder :: "./res/cards_png/"
    for suit in Card_Suit do for  val in Card_Value{
	filename := card_filename(val, suit)
	fullpath := fmt.ctprintf("%s%s", folder, filename)
 	texture := rl.LoadTexture(fullpath)
	if texture == rl.Texture2D({}) do return false	
	card_textures[filename] = texture
    }
    return true
}

unload_card_textures :: proc() {
    for _, texture in card_textures do rl.UnloadTexture(texture)
}

draw_card_backside :: proc(rect: rl.Rectangle) {
    BACKSIDE_COLOR : rl.Color : {0xbb, 0x10, 0x10, 0xff}
    BACKSIDE_BORDER_COLOR : rl.Color : {0x18, 0x18, 0x18, 0xff}
    BORDER_WIDTH :: 4
    rl.DrawRectangleRec(rect, BACKSIDE_COLOR)
    rl.DrawRectangleLinesEx(rect, BORDER_WIDTH, BACKSIDE_BORDER_COLOR)
}

draw_no_card :: proc(rect: rl.Rectangle) {
    NO_CARD_COLOR : rl.Color : {0x18, 0x18, 0x18, 0x50}
    rl.DrawRectangleRec(rect, NO_CARD_COLOR)
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Alone")
    defer rl.CloseWindow()
    if !load_card_textures() do return
    defer unload_card_textures()

    game_init()
    defer game_destroy()
    
    for !rl.WindowShouldClose(){
	rl.BeginDrawing()
	rl.ClearBackground(BG_COLOR)
	mouse_pos := rl.GetMousePosition()

	game_state.hovered_data = {}
	
	// Draw pile and handle hovering over it
	PILES_INITIAL_X :: PILES_PADDING
	PILES_INITIAL_Y :: 250.0

	for pile, i in game_state.piles {
	    x : f32 = PILES_INITIAL_X + f32(i) * (CARD_WIDTH + PILES_PADDING)
	    y : f32 = PILES_INITIAL_Y
	    card_rec : rl.Rectangle = {x, y, CARD_WIDTH, CARD_HEIGHT}
	    draw_no_card(card_rec)
	    if rl.CheckCollisionPointRec(mouse_pos, card_rec) && len(pile.cards) == 0{
		game_state.hovered_data = {.Piles, i, 0}
	    }
	    for j in 0..<pile.n_of_face_down {
		draw_card_backside(card_rec)
		card_rec.y += FOUNDATION_VERT_PADDING
	    }
	    for j in pile.n_of_face_down..<len(pile.cards) {
		card_rec_coll := card_rec
		if j < (len(pile.cards) - 1) do card_rec_coll.height -= CARD_HEIGHT * 5.0/6.0
		if rl.CheckCollisionPointRec(mouse_pos, card_rec_coll) {
		    game_state.hovered_data = {.Piles, i, j}
		}
		hv_data := game_state.hovered_data
		cl_data := game_state.clicked_data
		switch {
		case cl_data.loc == .Piles && cl_data.id == i && j >= cl_data.depth :
		case hv_data.loc == .Piles && hv_data.id == i && j >= hv_data.depth :
		    rl.DrawTexturePro(pile.cards[j].texture, CARD_TEXTURE_RECTANGLE, card_rec, 0, 0, rl.YELLOW)
		case :
		    rl.DrawTexturePro(pile.cards[j].texture, CARD_TEXTURE_RECTANGLE, card_rec, 0, 0, rl.WHITE)
		}
		card_rec.y += FOUNDATION_VERT_PADDING
	    }
	}
	
	// Draw foundation and handle hovering over it
	FOUNDATION_INITIAL_X :: PILES_INITIAL_X + 3 * (CARD_WIDTH + PILES_PADDING)
	FOUNDATION_INITIAL_Y :: 20
	for i in 0..<4 {
	    x : f32 = FOUNDATION_INITIAL_X + f32(i) * (CARD_WIDTH + FOUNDATION_PADDING)
	    y : f32 = FOUNDATION_INITIAL_Y
	    rect : rl.Rectangle = {x, y, CARD_WIDTH, CARD_HEIGHT}
	    if rl.CheckCollisionPointRec(mouse_pos, rect) do game_state.hovered_data = {loc = .Foundation, id = i}
	    if game_state.foundations[i].value != EMPTY_CARD_VALUE {
		rl.DrawTexturePro(game_state.foundations[i].texture, CARD_TEXTURE_RECTANGLE, rect, 0, 0, rl.WHITE)
	    }
	    else do draw_no_card(rect)
	}

	// Draw stock and handle hovering over it
	STOCK_X :: PILES_PADDING
	STOCK_Y :: FOUNDATION_INITIAL_Y
	{
	    rect : rl.Rectangle = {STOCK_X, STOCK_Y, CARD_WIDTH, CARD_HEIGHT}
	    draw_card_backside(rect)
	    if rl.CheckCollisionPointRec(mouse_pos, rect) do game_state.hovered_data = {loc = .Stock}
	}

	// Draw waste and handle hovering over it
	WASTE_X :: PILES_PADDING + 1 * (CARD_WIDTH + PILES_PADDING)
	WASTE_Y :: 20
	{
	    rect : rl.Rectangle = {WASTE_X, WASTE_Y, CARD_WIDTH, CARD_HEIGHT}
	    draw_no_card(rect)
	    if rl.CheckCollisionPointRec(mouse_pos, rect) do game_state.hovered_data = {loc = .Waste}
	    switch {
	    case game_state.clicked_data.loc == .Waste && len(game_state.waste) > 1:
		rl.DrawTexturePro(game_state.waste[len(game_state.waste) - 2].texture, CARD_TEXTURE_RECTANGLE, rect, 0, 0, rl.YELLOW)
	    case game_state.hovered_data.loc == .Waste && game_state.clicked_data.loc != .Waste && len(game_state.waste) > 0:
		rl.DrawTexturePro(game_state.waste[len(game_state.waste) - 1].texture, CARD_TEXTURE_RECTANGLE, rect, 0, 0, rl.YELLOW)
	    case game_state.hovered_data.loc != .Waste && game_state.clicked_data.loc != .Waste && len(game_state.waste) > 0:
		rl.DrawTexturePro(game_state.waste[len(game_state.waste) - 1].texture, CARD_TEXTURE_RECTANGLE, rect, 0, 0, rl.WHITE)
	    }
	}
	
	// Handle button pressed
	handle_pressed: if rl.IsMouseButtonPressed(.LEFT) && game_state.hovered_data != {} {
	    card_pos : rl.Vector2
	    switch hv_data := game_state.hovered_data; hv_data.loc {
	    case .Piles :
		card_pos = {PILES_INITIAL_X, PILES_INITIAL_Y}
		card_pos.x += (PILES_PADDING + CARD_WIDTH) * f32(hv_data.id)
		card_pos.y += (FOUNDATION_VERT_PADDING) * f32(hv_data.depth)
	    case .Waste:
		card_pos = {WASTE_X, WASTE_Y}
	    case .Stock:
		if len(game_state.stock) <= 0 do break handle_pressed
		append(&game_state.waste, pop(&game_state.stock))
		fallthrough
	    case .None, .Foundation:
		break handle_pressed
	    }
	    game_state.clicked_data.hovered_data = game_state.hovered_data
	    game_state.clicked_data.offset = mouse_pos - card_pos
	    fmt.printfln("debug: Clicked on %v", game_state.clicked_data)
	}

	// Handle button released
	handle_release: if rl.IsMouseButtonReleased(.LEFT) && game_state.clicked_data != {} {
	    cl_data := game_state.clicked_data
	    hv_data := game_state.hovered_data
	    defer game_state.clicked_data = {}
	    switch hv_data.loc {
	    case .Piles:
		target := &game_state.piles[hv_data.id]
		switch cl_data.loc {
		case .Piles:
		    if hv_data.id == cl_data.id do break handle_release
		    source := &game_state.piles[cl_data.id]
		    card_value := source.cards[cl_data.depth].value
		    if len(target.cards) == 0 || card_value < target.cards[len(target.cards) - 1].value {
			append(&target.cards, ..source.cards[cl_data.depth:])
			resize(&source.cards, cl_data.depth)
			if source.n_of_face_down == len(source.cards) && source.n_of_face_down > 0 do source.n_of_face_down -= 1
		    } 
		case .Foundation, .Stock:
		    panic("You shouldn't be here")
		case .Waste:
		    source := &game_state.waste
		    card_value := source[len(source) - 1].value
		    if len(target.cards) == 0 || card_value < target.cards[len(target.cards) - 1].value {
			append(&target.cards, pop(source))
		    } 

		case .None:
		}
	    case .Foundation:  
		target := &game_state.foundations[hv_data.id]
		switch cl_data.loc {
		case .Piles:
		    source := &game_state.piles[cl_data.id]
		    c := source.cards[len(source.cards) - 1]
		    if (len(source.cards) - 1) != cl_data.depth do break handle_release
		    if (target.value == EMPTY_CARD_VALUE && c.value == .Ace ||
			(int(c.value) - int(target.value) == 1) && target.suit == c.suit) {
			target^ = pop(&source.cards)
			if source.n_of_face_down == len(source.cards) && source.n_of_face_down > 0 do source.n_of_face_down -= 1
		    } 
		case .Foundation, .Stock:
		    panic("You shouldn't be here")
		case .Waste:
		    source := &game_state.waste
		    c := source[len(source) - 1]
		    if (target.value == EMPTY_CARD_VALUE && c.value == .Ace ||
			(int(c.value) - int(target.value) == 1) && target.suit == c.suit) {
			target^ = pop(source)
		    } 
		case .None:
		}

	    case .Waste, .Stock:
	    case .None:
	    }
	}

	// Draw flying card
	if cl_data := game_state.clicked_data; cl_data != {} {
	    pos := mouse_pos - cl_data.offset
	    cards := game_state.piles[cl_data.id].cards
	    switch cl_data.loc {
	    case .Waste:
		c := game_state.waste[len(game_state.waste) - 1]
		rl.DrawTexturePro(c.texture, CARD_TEXTURE_RECTANGLE, {pos.x, pos.y, CARD_WIDTH, CARD_HEIGHT}, 0, 0, rl.YELLOW)
	    case .Piles: 
		for c in cards[cl_data.depth:] {
		    pos.y += FOUNDATION_VERT_PADDING
		    rl.DrawTexturePro(c.texture, CARD_TEXTURE_RECTANGLE, {pos.x, pos.y, CARD_WIDTH, CARD_HEIGHT}, 0, 0, rl.YELLOW)
		}
	    case .None, .Foundation, .Stock:
		panic("You shouldn't be here")
	    }
	    
	}

	won_game := true
	for f in game_state.foundations do won_game &= f.value == .King
	if won_game do break
	rl.EndDrawing()
    }
}

//! The color selection widget is, not surprisingly, a widget for
//! interactive selection of colors.  This composite widget lets the
//! user select a color by manipulating RGB (Red, Green, Blue) and HSV
//! (Hue, Saturation, Value) triples. This is done either by adjusting
//! single values with sliders or entries, or by picking the desired
//! color from a hue-saturation wheel/value bar.  Optionally, the
//! opacity of the color can also be set.
//! 
//! The color selection widget currently emits only one signal,
//! "color_changed", which is emitted whenever the current color in the
//! widget changes, either when the user changes it or if it's set
//! explicitly through set_color().
//! 
//!@expr{ GTK1.ColorSelection()@}
//!@xml{<image>../images/gtk1_colorselection.png</image>@}
//!
//!
//!

inherit GTK1.Vbox;

protected GTK1.ColorSelection create( );
//! Create a new color selection.
//!
//!

array get_color( );
//!  When you need to query the current color, typically when you've
//!  received a "color_changed" signal, you use this function. The
//!  return value is an array of floats, See the set_color() function
//!  for the description of this array.
//!
//!

GTK1.ColorSelection set_color( array color );
//! You can set the current color explicitly by calling this function
//! with an array of colors (floats). The length of the array depends
//! on whether opacity is enabled or not. Position 0 contains the red
//! component, 1 is green, 2 is blue and opacity is at position 3 (only
//! if opacity is enabled, see set_opacity()) All values are between
//! 0.0 and 1.0
//!
//!

GTK1.ColorSelection set_update_policy( int policy );
//! one of @[UPDATE_ALWAYS], @[UPDATE_CONTINUOUS], @[UPDATE_DELAYED], @[UPDATE_DISCONTINUOUS] and @[UPDATE_IF_VALID].
//! 
//! The default policy is GTK1.UpdateContinuous which means that the
//! current color is updated continuously when the user drags the
//! sliders or presses the mouse and drags in the hue-saturation wheel
//! or value bar. If you experience performance problems, you may want
//! to set the policy to GTK1.UpdateDiscontinuous or GTK1.UpdateDelayed.
//!
//!

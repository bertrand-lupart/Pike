//! Glade is a free GUI builder for GTK2+ and Gnome.  It's normally used to
//! create C-code, but can also produce code for other languages.  Libglade
//! is a utility library that builds the GI from the Glade XML save files.
//! This module uses libglade and allows you to easily make GUI designs to be
//! used with your Pike applications.
//!
//!

inherit G.Object;

static GTK2.GladeXML create( string filename_or_buffer, int|void size, string|void root, string|void domain );
//! Creates a new GladeXML object (and the corresponding widgets) from the
//! XML file.  Optionally it will only build the interface from the widget
//! node root.  This feature is useful if you only want to build say a
//! toolbar or menu from the XML file, but not the window it is embedded in.
//! Note also that the XML parse tree is cached to speed up creating another
//! GladeXML object from the same file.  The third optional argument is used to
//! specify a different translation domain from the default to be used.
//! If xml description is in a string buffer instead, specify the size (or -1
//! to auto-calculate).  If size is 0, then it will assume a file with root
//! and/or domain specified.
//!
//!

int get_signal_id( GTK2.Widget widget );
//! Used to get the signal id attached to a GladeXML object.
//!
//!

GTK2.Widget get_widget( string name );
//! This function is used to get the widget corresponding to name in the
//! interface description.  You would use this if you have to do anything to
//! the widget after loading.
//!
//!

string get_widget_name( GTK2.Widget widget );
//! Used to get the name of a widget that was generated by a GladeXML object.
//!
//!

array get_widget_prefix( string name );
//! This function is used to get a list GTK2.Widgets with names that start with
//! the string name in the interface description.
//!
//!

GTK2.GladeXML signal_autoconnect( mapping callbacks, mixed data );
//! Try to connect functions to all signals in the interface.  The mapping
//! should consist of handler name : function pairs.  The data argument will
//! be saved and sent as the first argument to all callback functions.
//!
//!
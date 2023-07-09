#include "my_application.h"

#include <iostream>

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

GdkWindowEdge edgeFromDragFlags(bool north, bool south, bool west, bool east) {
  if (north && west) return GDK_WINDOW_EDGE_NORTH_WEST;
  if (north && east) return GDK_WINDOW_EDGE_NORTH_EAST;
  if (south && west) return GDK_WINDOW_EDGE_SOUTH_WEST;
  if (south && east) return GDK_WINDOW_EDGE_SOUTH_EAST;
  if (north) return GDK_WINDOW_EDGE_NORTH;
  if (south) return GDK_WINDOW_EDGE_SOUTH;
  if (west) return GDK_WINDOW_EDGE_WEST;
  if (east) return GDK_WINDOW_EDGE_EAST;
}

const gchar *cursorFromDragFlags(bool north, bool south, bool west, bool east) {
  if (north && west) return "nw-resize";
  if (north && east) return "ne-resize";
  if (south && west) return "sw-resize";
  if (south && east) return "se-resize";
  if (north) return "n-resize";
  if (south) return "s-resize";
  if (west) return "w-resize";
  if (east) return "e-resize";
}

GtkWindow* window_sub;
bool sub_showing = true;
int sub_position[4] = {0, 0, 0, 0};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean mouse_move_event_clbk(GtkWidget *widget, GdkEvent *event) {
  GdkEventMotion motion = event->motion;
  int width = gtk_widget_get_allocated_width(widget);
  int height = gtk_widget_get_allocated_height(widget);
  bool northDrag = false;
  bool westDrag = false;
  bool eastDrag = false;
  bool southDrag = false;
  if (motion.x < 16) westDrag = true;
  if (motion.x > (width - 16)) eastDrag = true;
  if (motion.y < 16) northDrag = true;
  if (motion.y > (height - 16)) southDrag = true;
  bool isResizeArea = northDrag | westDrag | southDrag | eastDrag;
  GdkDisplay *display = gtk_widget_get_display(widget);
  GdkCursor *cursor;
  if (isResizeArea) {
    cursor = gdk_cursor_new_from_name(
      display,
      cursorFromDragFlags(northDrag, southDrag, westDrag, eastDrag)
    );
  } else {
    cursor = gdk_cursor_new_from_name(display, "grab");
  }
  gdk_window_set_cursor(gtk_widget_get_window(widget), cursor);
  g_object_unref(cursor);
  return TRUE;
}

static gboolean button_press_event_clbk(GtkWidget *widget, GdkEvent *event) {
  GdkEventButton button = event->button;
  int width = gtk_widget_get_allocated_width(widget);
  int height = gtk_widget_get_allocated_height(widget);
  bool northDrag = false;
  bool westDrag = false;
  bool eastDrag = false;
  bool southDrag = false;
  if (button.x < 16) westDrag = true;
  if (button.x > (width - 16)) eastDrag = true;
  if (button.y < 16) northDrag = true;
  if (button.y > (height - 16)) southDrag = true;
  bool isResizeEvent = northDrag | westDrag | southDrag | eastDrag;
  if (isResizeEvent) {
    gtk_window_begin_resize_drag(
      window_sub,
      edgeFromDragFlags(northDrag, southDrag, westDrag, eastDrag),
      button.button,
      button.x_root,
      button.y_root,
      button.time
    );
  } else {
    gtk_window_begin_move_drag(
      window_sub,
      button.button,
      button.x_root,
      button.y_root,
      button.time
    );
  }
  return TRUE;
}

static void update_position() {
  gtk_window_get_position(window_sub, &(sub_position[0]), &(sub_position[1]));
  sub_position[2] = gtk_widget_get_allocated_width((GtkWidget *)window_sub);
  sub_position[3] = gtk_widget_get_allocated_height((GtkWidget *)window_sub);
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call, gpointer user_data) {
  const gchar *method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "showSubwindow") == 0) {
    gtk_window_present(window_sub);
    gtk_window_set_keep_above(window_sub, true);
    gtk_window_move(window_sub, sub_position[0], sub_position[1]);
    sub_showing = true;
    g_autoptr(FlValue) result = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "hideSubwindow") == 0) {
    gtk_widget_hide((GtkWidget *)window_sub);
    sub_showing = false;
    g_autoptr(FlValue) result = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "closeSubwindow") == 0) {
    gtk_window_close(window_sub);
    g_autoptr(FlValue) result = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getSubwindowBox") == 0) {
    if (sub_showing) {
      update_position();
    }
    g_autoptr(FlValue) result = fl_value_new_int32_list(sub_position, 4);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  fl_method_call_respond(method_call, response, &error);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "rattata_vision");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "rattata_vision");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  // Open a sub window to scan screen
  window_sub = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window_sub, 320, 180);
  gtk_window_set_decorated(window_sub, false);
  GdkGeometry minGeometry;
  minGeometry.min_width = 50;
  minGeometry.min_height = 50;
  gtk_window_set_geometry_hints(window_sub, NULL, &minGeometry, GDK_HINT_MIN_SIZE);
  GdkColor color;
  color.red = 0xffff;
  color.green = 0x0000;
  color.blue = 0x0000;
  gtk_widget_modify_bg((GtkWidget *)window_sub, GTK_STATE_NORMAL, &color);
  gtk_widget_show(GTK_WIDGET(window_sub));
  gtk_window_set_keep_above(window_sub, true);
  gtk_widget_set_opacity((GtkWidget *)window_sub, 0.2);
  update_position();

  // Bind mouse down event to resize/pan drag event
  g_signal_connect((GtkWidget *)window_sub, "button-press-event", G_CALLBACK(button_press_event_clbk), NULL);

  // Bind mouse movement events to update cursor
  gtk_widget_add_events((GtkWidget *)window_sub, GDK_POINTER_MOTION_MASK);
  g_signal_connect((GtkWidget *)window_sub, "motion-notify-event", G_CALLBACK(mouse_move_event_clbk), NULL);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Register method channel and callbacks
  FlEngine *engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlBinaryMessenger) messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
    messenger,
    "subwindow_channel",
    FL_METHOD_CODEC(codec)
  );
  fl_method_channel_set_method_call_handler(
    channel, 
    method_call_cb,  
    g_object_ref(view),
    g_object_unref
  );

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}

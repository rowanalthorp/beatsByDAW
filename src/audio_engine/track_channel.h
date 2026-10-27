#ifndef TRACK_CHANNEL_H
#define TRACK_CHANNEL_H

#include <godot_cpp/classes/ref_counted.hpp>

// we are gonna use a ref counted cause auto garbage collection
namespace godot {
    class TrackChannel : public RefCounted {
        GDCLASS(TrackChannel, RefCounted)
    }
    private:
    
    public:
        TrackChannel();
        ~TrackChannel();

        void play();
        void pause();

        void
}
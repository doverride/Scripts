#!/bin/sh --

gst-launch-1.0 -v -e v4l2src device=/dev/video0 ! queue ! \
    video/x-h264,width=1280,height=720,framerate=30/1 ! \
	h264parse ! avdec_h264 ! xvimagesink sync=false

# step1 raw

# gst-launch v4l2src ! 'video/x-raw-yuv,width=640,height=480,framerate=30/1' ! \
# tee name=t_vid ! queue ! videoflip method=horizontal-flip ! \
# xvimagesink sync=false t_vid. ! queue ! \
# videorate ! 'video/x-raw-yuv,framerate=30/1' ! queue ! mux. \
# alsasrc device=hw:1,0 ! audio/x-raw-int,rate=48000,channels=2,depth=16 ! queue ! \
# audioconvert ! queue ! mux. avimux name=mux ! \
# filesink location=me_dancing_funny.avi

# step2 h264

# gst-launch filesrc location=me_funny_dancing.avi ! \
# decodebin name=decode decode. ! queue ! x264enc ! mp4mux name=mux ! \
# filesink location=me_funny_dancing.mp4 decode. ! \
# queue ! audioconvert ! faac ! mux.

#EOF


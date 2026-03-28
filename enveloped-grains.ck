@import "classes/granular_class.ck"
@import "classes/ring-mod-encoder.ck"

// defines
16 => int N_GRAINS;

// patch
Granulator grains("audio/screaming_05.08.2025_excerpt.wav")[N_GRAINS] => Envelope env[N_GRAINS] => DelayA echo(12::samp, 16::samp)[N_GRAINS] => Gain vol(0.5)[N_GRAINS] => blackhole;
// dry
env => vol => blackhole;

// delay feedback
Gain feedback(0.7)[N_GRAINS] => echo => feedback;

// encode & summation
Encode3 encoders[N_GRAINS];
OrderGain3 summation(1.0/16.0);

// recorder
WvOut recorder[summation.channels()];

// recording 
fun void beginRecord(OrderGain3 sum, WvOut recorder[])
{
    for(int i; i < sum.channels(); i++)
    {
        string index;
        if(i < 10) "0"+i => index;
        else " "+i => index;
        recorder[i].wavFilename("recordings/"+"enveloped-grains"+"-"+index+".wav");
        sum.chan(i) => recorder[i] => blackhole;
    }
}

// given a rate randomly turn on an envelope repeatedly
fun void randomStrike(Envelope env)
{
    while(true)
    {
        env.keyOn();
        env.duration() => now;
        Math.random2f(1.0, 100.0) * env.duration() => now;
        env.keyOff();
        env.duration() => now;
    }
}

// start recording
spork ~ beginRecord(summation, recorder);

// initialize grains and encoders
for(int i; i < N_GRAINS; i++)
{
    // patch in
    vol[i] => encoders[i] => summation;
    // encoders W to dac
    encoders[i].chan(0) => dac;
    dac.gain(1.0/N_GRAINS);
    // set random position in the frontal and northern hemispheres
    encoders[i].pos(Math.random2f(-90.0, 90.0), Math.random2f(-15.0, 15.0));
    // random feedback coefficient
    feedback[i].gain(Math.random2f(0.5, 0.7));
    // envelope time
    env[i].duration(Math.random2f(1.0, 20.0)::ms);
    // set position
    grains[i].instantPosition(Math.random2f(0.0, 1.0));
    // grain size
    grains[i].grainSize(Math.random2f(1.0, 72.0));
    // play
    grains[i].play();
    // lastly, spork~!
    spork ~ randomStrike(env[i]);
}

// hid
Hid mouse;
HidMsg msg;
// open mouse
if(!mouse.openMouse(0))  {<<< "HID: Mouse could not be opened." >>>; me.exit();}

while(true)
{
    // listen loop
    while(mouse.recv(msg))
    {
        mouse => now;
        if(msg.isMouseMotion())
        {
            for(int i; i < N_GRAINS; i++)
            {
                grains[i].grainSize((msg.scaledCursorX * 50.0) + 15.0);
                grains[i].setPosition(msg.scaledCursorY);
                // of random polarity, multiply the current azimuth by deltaX + deltaY and add it to the current azimuth
                encoders[i].azi(encoders[i].azi() + (Math.random2f(-1.0, 1.0) * (msg.deltaX + msg.deltaY) * encoders[i].azi()));
            }
            // throttle
            10::ms => now;
        }
        else if(msg.isButtonDown())
        {
            me.exit();
        }
    }
}

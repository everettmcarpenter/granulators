//-----------------------------------------------------------
// name: ring-mod-encoder.ck
// author: everett m. carpenter
// desc: a psuedo spatial ring-modulator. using an input, 
//       this encoder creates two equally pitchshifted
//       sidebands which are then spatialized according
//       to the dry (input) source.
//
//          increase in pitchshift = widening of sources
//      
//       by default, the widest pitchshifts will go is 
//       90 degrees and a factor of 8.0 (7? octaves above),
//       but can be changed with maxWidth and spreadFactor.
//       there is also a mix parameter which turns up
//       both sidebands at 1.0 and they are silent at
//       0.0
//-----------------------------------------------------------

public class RingModEncoder extends Chugraph
{
    PitShift upDown[2];
    Encode4 enc[3];
    Gain wet[2];
    OrderGain4 out(1.0/3.0);
    // how high are we pitch shifting 
    8.0 => float spreadFactor;
    // how wide are we going (90 == perpendicular to source)
    90.0 => float maxWidth;

    fun void RingModEncoder()
    {
        // set mix to wet
        upDown[0].mix(1.0);
        upDown[1].mix(1.0);
        // audio routing
        inlet => enc[0] => out;
        inlet => upDown[0] => wet[0] => enc[1] => out;
        inlet => upDown[1] => wet[1] => enc[2] => out;
        // init
        enc[0].pos(0.0, 0.0);
    }

    // change partials and position (assume we are working from [0.0,spreadFactor])
    fun void widen(float delta)
    {
        delta => upDown[0].shift;
        -delta => upDown[1].shift;
        enc[0].azi() + enc[1].azi() + (delta/spreadFactor) => enc[1].azi;
        enc[0].azi() + (enc[2].azi() - (delta/spreadFactor)) => enc[2].azi;
    }

    // move center point (dry)
    fun void rotate(float delta)
    {
        enc[0].azi() + delta => enc[0].azi;
        enc[0].azi() + (upDown[0].shift()/spreadFactor) * maxWidth => enc[1].azi;
        enc[0].azi() + (upDown[1].shift()/spreadFactor) * maxWidth => enc[2].azi;
    }

    // position
    fun void position(float azimuth, float elevation)
    {
        enc[0].pos(azimuth, elevation);
        enc[0].azi() + (upDown[0].shift()/spreadFactor) * maxWidth => enc[1].azi;
        enc[0].azi() + (upDown[1].shift()/spreadFactor) * maxWidth => enc[2].azi;
    }

    // mix adjustment
    fun void mix(float nmix)
    {
        nmix => wet[0].gain => wet[1].gain;
        1.0/(3.0 -((1.0 - nmix) * 2.0)) => out.gain;
    }
}

// record
fun void beginRecord(OrderGain2 sum, WvOut recorder[])
{
    for(int i; i < sum.channels(); i++)
    {
        recorder[i].wavFilename("../recordings/"+Machine.timeOfDay()+"-"+i+".wav");
        sum.chan(i) => recorder[i] => blackhole;
    }
}

// start
SinOsc sine => RingModEncoder ring => blackhole;
// set width
ring.widen(2.0);

// recorder
WvOut bformat[9];

// lets record it
spork ~ beginRecord(ring.out, bformat);

for(int i; i < 100; i++)
{
    ring.rotate(i * (360.0/100.0));
    ring.widen(i * (8.0/100.0));
    ring.mix(i * 1.0/100.0);
    // pass time
    100::ms => now;
}
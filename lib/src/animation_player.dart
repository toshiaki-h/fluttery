import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Development UI that let's a user play an animation forward and backward to
/// fine-tune the animation.
///
/// An animation is represented as a [PlayableAnimation] which itself is comprised
/// of an ordered list of [Phase]s that represent transitions forward and backward.
///
/// The [AnimationPlayer] UI displays each phase and shows the phases that have
/// already been played, as well as the progress of the current phase.  The UI
/// also provides buttons to play the next phase or play the previous phase.
///
/// To use [AnimationPlayer], provide a [PlayableAnimation] by creating one with
/// a series of [Phase]s.
class AnimationPlayer extends StatefulWidget {

  final PlayableAnimation playableAnimation;

  AnimationPlayer({
    @required this.playableAnimation,
  }) {
    assert(playableAnimation != null);
  }

  @override
  _MultiPhaseAnimationTesterState createState() => new _MultiPhaseAnimationTesterState();
}

class _MultiPhaseAnimationTesterState extends State<AnimationPlayer> with TickerProviderStateMixin {

  static const STANDARD_PHASE_TIME = 250;

  int activePhase = 0;
  double phaseProgress = 0.0;
  double playbackSpeed = 1.0;
  bool playingForward = true;
  AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = new AnimationController(
      vsync: this,
    )
      ..addListener(() {
        setState(() {
          phaseProgress = playingForward
              ? animationController.value
              : 1.0 - animationController.value;

          final animationPhase = widget.playableAnimation.phases[activePhase];
          if (playingForward) {
            animationPhase.forward(phaseProgress);
          } else {
            if (animationPhase.isUniform) {
              animationPhase.reverse(1.0 - phaseProgress);
            } else {
              animationPhase.reverse(phaseProgress);
            }
          }
        });
      })
      ..addStatusListener((status) {
        if (AnimationStatus.forward == status) {
          setState(() => playingForward = true);
        } else if (AnimationStatus.reverse == status) {
          setState(() => playingForward = false);
        } else if (AnimationStatus.dismissed == status) {
          print('Animation reached 0.0.');
        } else if (AnimationStatus.completed == status) {
          print('Animation reached 1.0.');
          // If we just finished playing forward, increment active phase.
          if (playingForward && activePhase < widget.playableAnimation.phases.length) {
            ++activePhase;
            phaseProgress = 0.0;
          }
        }

        print('New activePhase: $activePhase, phaseProgress: $phaseProgress');
      });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  _playPhaseForward() {
    if (activePhase < widget.playableAnimation.phases.length) {
      animationController.duration = new Duration(milliseconds: (STANDARD_PHASE_TIME / playbackSpeed).round());
      animationController.forward(from: 0.0);
    }
  }

  _playPreviousPhaseInReverse() {
    if (activePhase >= 1) {
      setState(() {
        --activePhase;
        phaseProgress = 1.0;

        animationController.duration = new Duration(milliseconds: (STANDARD_PHASE_TIME / playbackSpeed).round());
        animationController.reverse(from: 1.0);
      });
    }
  }

  _buildPhaseIndicators() {
    List<Widget> phases = [];
    for (var i = 0; i < widget.playableAnimation.phases.length; ++i) {
      var percent = 0.0;
      final isActivePhase = i == activePhase;

      if (i < activePhase) {
        percent = 1.0;
      } else if (playingForward && isActivePhase) {
        percent = phaseProgress;
      } else if (!playingForward && isActivePhase) {
        percent = 1.0 - phaseProgress;
      }

      print("Playback percent: $percent");

      phases.add(
          new Expanded(
            child: new Padding(
                padding: const EdgeInsets.all(10.0),
                child: new Column(
                  children: [
                    // Forward progress indicator
                    new Row(
                      children: [
                        new Expanded(
                          flex: (percent * 100).round(),
                          child: new Container(
                            height: 5.0,
                            color: Colors.blue,
                          ),
                        ),
                        new Expanded(
                          flex: ((1.0 - percent) * 100).round(),
                          child: new Container(
                            height: 5.0,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
            ),
          )
      );
    }

    return phases;
  }

  @override
  Widget build(BuildContext context) {
    final phaseIndicators = _buildPhaseIndicators();

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Playback speed slider
        new Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15.0),
          child: new Text(
            'Playback Speed:',
          ),
        ),
        new Padding(
          padding: const EdgeInsets.all(15.0),
          child: new Slider(
              activeColor: Colors.blue,
              value: playbackSpeed,
              min: 0.0,
              max: 2.0,
              onChanged: (newValue) {
                setState(() => playbackSpeed = newValue);
              }
          ),
        ),

        // Phase progress indicators
        new Row(
          children: phaseIndicators,
        ),

        // Playback control buttons
        new Row(
          children: [
            new Expanded(
              child: new FlatButton(
                child: new Text(
                  '<- Prev',
                ),
                onPressed: () {
                  _playPreviousPhaseInReverse();
                },
              ),
            ),
            new Expanded(
              child: new FlatButton(
                child: new Text(
                  'Next ->',
                ),
                onPressed: () {
                  _playPhaseForward();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A series of [Phase]s such that each [Phase] can be played forward and
/// backward.
class PlayableAnimation {
  final List<Phase> phases;

  PlayableAnimation({
    @required this.phases,
  });
}

/// A transition that supports forward and reverse playback.
///
/// A [Phase] can be created with a single uniform [Transition] or with a
/// forward and reverse [Transition] for bidirectional control.
class Phase<DataType, ViewModelType> {
  final Transition _uniformTransition;
  final Transition _forward;
  final Transition _reverse;

  // A phase that uses the same Transition to go forward and back. A uniform
  // Transition is passed values starting at 0.0 -> 1.0 going forward, and then
  // 1.0 -> 0.0 going in reverse.
  Phase.uniform({
    uniformTransition,
  }) : _uniformTransition = uniformTransition, _forward = null, _reverse = null;

  // A phase that uses 2 different Transitions to go forward vs reverse. Both
  // bidirectional Transitions are passed values starting at 0.0 -> 1.0, regardless
  // of whether it's the forward or reverse Transition.
  Phase.bidirectional({
    forward,
    reverse,
  }) : _forward = forward, _reverse = reverse, _uniformTransition = null;

  get isUniform => _uniformTransition != null;

  get forward {
    return null != _uniformTransition ? _uniformTransition : _forward;
  }

  get reverse {
    return null != _uniformTransition ? _uniformTransition : _reverse;
  }
}

typedef Transition = Function(double percent);
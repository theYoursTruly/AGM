/*
 * Author: KoffeinFlummi
 * 
 * Called when some dude gets shot. Or stabbed. Or blown up. Or pushed off a cliff. Or hit by a car. Or burnt. Or poisoned. Or gassed. Or cut. You get the idea.
 * 
 * Arguments:
 * 0: Unit that got hit (Object)
 * 1: Name of the selection that was hit (String); "" for structural damage
 * 2: Amount of damage inflicted (Number)
 * 3: Shooter (Object); Null for explosion damage, falling, fire etc.
 * 4: Projectile (Object)
 * 
 * Return value:
 * Damage value to be inflicted (optional)
*/

#define REVIVETHRESHOLD 0.8
#define UNCONSCIOUSNESSTHRESHOLD 0.65
#define LEGDAMAGETHRESHOLD1 1.5
#define LEGDAMAGETHRESHOLD2 3
#define PRONEANIMATION "abcdefg"
#define ARMDAMAGETHRESHOLD 0.7
#define PAINKILLERTHRESHOLD 0.1
#define PAINLOSS 0.005
#define BLOODTHRESHOLD1 0.4
#define BLOODTHRESHOLD2 0.2
#define BLOODLOSSRATE 0.005
#define AUTOHEALRATE 0.005

_unit = _this select 0;
_selectionName = _this select 1;
_damage = _this select 2;
_source = _this select 3;
_projectile = _this select 4;

// Prevent unnecessary processing
if (damage _unit == 1) exitWith {};

// Code to be executed AFTER damage was dealt
null = [_unit, damage _unit] spawn {
  _unit = _this select 0;
  _damageold = _this select 1;
  _painold = _unit getVariable "BWA3_Pain";

  sleep 0.001;

  _armdamage = (_unit getHitPointDamage "HitLeftShoulder" + _unit getHitPointDamage "HitLeftArm" + _unit getHitPointDamage "HitLeftForeArm" + _unit getHitPointDamage "HitRightShoulder" + _unit getHitPointDamage "HitRightArm" + _unit getHitPointDamage "HitRightForeArm");
  _legdamage = (_unit getHitPointDamage "HitLeftUpLeg" + _unit getHitPointDamage "HitLeftLeg" + _unit getHitPointDamage "HitLeftFoot" + _unit getHitPointDamage "HitRightUpLeg" + _unit getHitPointDamage "HitRightLeg" + _unit getHitPointDamage "HitRightFoot");

  // Reset "unused" hitpoints.
  _unit setHitPointDamage ["HitLegs", 0];
  _unit setHitPointDamage ["HitHands", 0];
  
  /*
  // Handle death and unconsciousness
  if (damage _unit > UNCONSCIOUSNESSTHRESHOLD and !(_unit getVariable "BWA3_Unconscious")) then {
    //[_unit] call BWA3_Medical_fnc_knockOut;
  };
  if (damage _unit > REVIVETHRESHOLD) then {
    // Determine if unit is revivable.
    if (_unit getHitPointDamage "HitHead" < 0.5 and _unit getHitPointDamage "HitBody" < 1 and _unit getVariable "BWA3_Blood" > 0.2) then {
      _unit setVariable ["BWA3_Dead", 1];
    } else {
      _unit setDamage 1;
    };
  };
  */

  // Handle leg damage symptoms
  if (_legdamage >= LEGDAMAGETHRESHOLD1 and _legdamage < LEGDAMAGETHRESHOLD2) then {
    // lightly wounded, limit walking speed
    _unit setHitPointDamage ["HitLegs", 1];
  };
  if (_legdamage >= LEGDAMAGETHRESHOLD2) then {
    // heavily wounded, stop unit from walking alltogether
    // TODO: replace playMoveNow with setUnitPos for AI units
    if !(_unit getVariable "BWA3_NoLegs") then {
      _unit setVariable ["BWA3_NoLegs", true, true];
      _unit spawn {
        _unit = _this select 0;
        _legdamage = (_unit getHitPointDamage "HitLeftUpLeg" + _unit getHitPointDamage "HitLeftLeg" + _unit getHitPointDamage "HitLeftFoot" + _unit getHitPointDamage "HitRightUpLeg" + _unit getHitPointDamage "HitRightLeg" + _unit getHitPointDamage "HitRightFoot");
        _unit playMoveNow "proneAnimation"; // fill this in
        while {_legdamage >= LEGDAMAGETHRESHOLD2} do {
          waitUntil {sleep 2; stance _unit != "PRONE"};
          _unit playMoveNow "proneAnimation"; // fill this in
        };
        _unit setVariable ["BWA3_NoLegs", false, true];
      };
    };
  };

  // Handle arm damage symptoms
  if (_unit getHitPointDamage "HitLeftShoulder" > ARMDAMAGETHRESHOLD or
      _unit getHitPointDamage "HitLeftArm" > ARMDAMAGETHRESHOLD or
      _unit getHitPointDamage "HitLeftForeArm" > ARMDAMAGETHRESHOLD or
      _unit getHitPointDamage "HitRightShoulder" > ARMDAMAGETHRESHOLD or
      _unit getHitPointDamage "HitRightArm" > ARMDAMAGETHRESHOLD or
      _unit getHitPointDamage "HitRightForeArm" > ARMDAMAGETHRESHOLD) then {

  };

  if (damage _unit * (_unit getVariable "BWA3_Painkiller") > _unit getVariable "BWA3_Pain") then {
    _unit setVariable ["BWA3_Pain", (damage _unit) * (_unit getVariable "BWA3_Painkiller")];
  };

  // Pain
  if (_unit == player) then {
    _unit spawn {
      if (_this getVariable "BWA3_InPain") exitWith {};
      _this setVariable ["BWA3_InPain", true];
      "chromAberration" ppEffectEnable true;
      _time = time;
      while {(_this getVariable "BWA3_Pain") > 0} do {
        "chromAberration" ppEffectAdjust [0.02 * (_this getVariable "BWA3_Pain"), 0.02 * (_this getVariable "BWA3_Pain"), false];
        "chromAberration" ppEffectCommit 1;
        sleep (1.5 - (_this getVariable "BWA3_Pain"));
        "chromAberration" ppEffectAdjust [0.2 * (_this getVariable "BWA3_Pain"), 0.2 * (_this getVariable "BWA3_Pain"), false];
        "chromAberration" ppEffectCommit 1;
        sleep 0.15;
        
        _pain = ((_this getVariable "BWA3_Pain") - PAINLOSS * ((time - _time) / 1)) max 0;
        _this setVariable ["BWA3_Pain", _pain];
        _time = time;
      };
      "chromAberration" ppEffectEnable false;
      _this setVariable ["BWA3_InPain", false];
    };
  };

  // Bleeding
  if !(_unit getVariable "BWA3_Bleeding") then {
    _unit setVariable ["BWA3_Bleeding", true];
    _unit spawn {
      while {_this getVariable "BWA3_Blood" > 0 and (_this getVariable "BWA3_Bleeding")} do {
        {
          _this setHitPointDamage [_x, ((_this getHitPointDamage _x) - AUTOHEALRATE) max 0];
        } forEach ["HitHead","HitBody","HitLeftShoulder","HitLeftArm","HitLeftForeArm","HitRightShoulder","HitRightArm","HitRightForeArm","HitLeftUpLeg","HitLeftLeg","HitLeftFoot","HitRightUpLeg","HitRightLeg","HitRightFoot"];
        if (damage _this == 0) exitWith {_this setVariable ["BWA3_Bleeding", false];};
        
        _blood = _this getVariable "BWA3_Blood";
        _blood = _blood - BLOODLOSSRATE * damage _this;
        _this setVariable ["BWA3_Blood", _blood];
        if (_blood < BLOODTHRESHOLD1 and !(_this getVariable "BWA3_Unconscious")) then {
          [_this] call BWA3_Medical_fnc_knockOut;
        };
        if (_blood < BLOODTHRESHOLD2) then {
          _this setDamage 1;
        };

        sleep 10;
      };
    };
  };

};

// reduce structural damage
if (_selectionName == "") exitWith {
  damage _unit + _damage / 3
};
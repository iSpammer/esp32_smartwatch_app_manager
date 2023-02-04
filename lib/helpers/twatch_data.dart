class TWatchData {
  double? _avgHR = 0;
  double? _currHR = 0;
  int? _temp = 0;
  double? _uva = 0;
  double? _uvb = 0;
  double? _uvindx = 0;
  double? _xacc = 0;
  double? _yacc = 0;
  double? _zacc = 0;
  DateTime? _timestamp;

  TWatchData(
      {double? avgHR,
        double? currHR,
        int? temp,
        double? uva,
        double? uvb,
        double? uvindx,
        double? xacc,
        double? yacc,
        double? zacc,
        DateTime? timestamp}) {
    if (avgHR != null) {
      this._avgHR = avgHR;
    }
    if (currHR != null) {
      this._currHR = currHR;
    }
    if (temp != null) {
      this._temp = temp;
    }
    if (uva != null) {
      this._uva = uva;
    }
    if (uvb != null) {
      this._uvb = uvb;
    }
    if (uvindx != null) {
      this._uvindx = uvindx;
    }
    if (xacc != null) {
      this._xacc = xacc;
    }
    if (yacc != null) {
      this._yacc = yacc;
    }
    if (zacc != null) {
      this._zacc = zacc;
    }
    if (timestamp != null) {
      this._timestamp = timestamp;
    }
  }

  double? get avgHR => _avgHR;
  set avgHR(double? avgHR) => _avgHR = avgHR;
  double? get currHR => _currHR;
  set currHR(double? currHR) => _currHR = currHR;
  int? get temp => _temp;
  set temp(int? temp) => _temp = temp;
  double? get uva => _uva;
  set uva(double? uva) => _uva = uva;
  double? get uvb => _uvb;
  set uvb(double? uvb) => _uvb = uvb;
  double? get uvindx => _uvindx;
  set uvindx(double? uvindx) => _uvindx = uvindx;
  double? get xacc => _xacc;
  set xacc(double? xacc) => _xacc = xacc;
  double? get yacc => _yacc;
  set yacc(double? yacc) => _yacc = yacc;
  double? get zacc => _zacc;
  set zacc(double? zacc) => _zacc = zacc;
  DateTime? get timestamp => _timestamp;
  set timestamp(DateTime? timestamp) => _timestamp = timestamp;

  TWatchData.fromJson(Map<String, dynamic> json) {
    _avgHR = json['avgHR'];
    _currHR = json['currHR'];
    _temp = json['temp'];
    _uva = json['uva'];
    _uvb = json['uvb'];
    _uvindx = json['uvindx'];
    _xacc = json['xacc'];
    _yacc = json['yacc'];
    _zacc = json['zacc'];
    _timestamp = DateTime.parse(json['timeStamp']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['avgHR'] = this._avgHR;
    data['currHR'] = this._currHR;
    data['temp'] = this._temp;
    data['uva'] = this._uva;
    data['uvb'] = this._uvb;
    data['uvindx'] = this._uvindx;
    data['xacc'] = this._xacc;
    data['yacc'] = this._yacc;
    data['zacc'] = this._zacc;
    data['timestamp'] = this._timestamp.toString();
    return data;
  }
}

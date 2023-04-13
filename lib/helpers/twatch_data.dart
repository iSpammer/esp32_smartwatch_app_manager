class TWatchData {
  double? _heartrate = 0;
  double? _xacc = 0;
  double? _yacc = 0;
  double? _zacc = 0;
  DateTime? _timestamp;

  TWatchData(
      {double? heartrate,
        double? xacc,
        double? yacc,
        double? zacc,
        DateTime? timestamp}) {
    if (heartrate != null) {
      this._heartrate = heartrate;
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

  double? get heartrate => _heartrate;
  set heartrate(double? heartrate) => _heartrate = heartrate;
  double? get xacc => _xacc;
  set xacc(double? xacc) => _xacc = xacc;
  double? get yacc => _yacc;
  set yacc(double? yacc) => _yacc = yacc;
  double? get zacc => _zacc;
  set zacc(double? zacc) => _zacc = zacc;
  DateTime? get timestamp => _timestamp;
  set timestamp(DateTime? timestamp) => _timestamp = timestamp;

  TWatchData.fromJson(Map<String, dynamic> json) {
    _heartrate = json['heartrate'];
    _xacc = json['xacc'];
    _yacc = json['yacc'];
    _zacc = json['zacc'];
    _timestamp = DateTime.parse(json['timeStamp']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['heartrate'] = this._heartrate;
    data['xacc'] = this._xacc;
    data['yacc'] = this._yacc;
    data['zacc'] = this._zacc;
    data['timestamp'] = this._timestamp.toString();
    return data;
  }
}

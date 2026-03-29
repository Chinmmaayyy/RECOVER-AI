-- Function to increment streak score atomically
CREATE OR REPLACE FUNCTION increment_streak(patient_id_input UUID)
RETURNS void AS $$
BEGIN
  UPDATE patients
  SET streak_score = streak_score + 1
  WHERE id = patient_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reset streak (called when Yellow/Red occurs)
CREATE OR REPLACE FUNCTION reset_streak(patient_id_input UUID)
RETURNS void AS $$
BEGIN
  UPDATE patients
  SET streak_score = 0
  WHERE id = patient_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: auto-reset streak on non-green check-in
CREATE OR REPLACE FUNCTION auto_manage_streak()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.triage_status = 'green' THEN
    PERFORM increment_streak(NEW.patient_id);
  ELSE
    PERFORM reset_streak(NEW.patient_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkin_streak_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION auto_manage_streak();
